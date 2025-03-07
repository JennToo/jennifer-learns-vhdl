#include <SDL2/SDL_log.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb_image_write.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_error.h>
#include <SDL2/SDL_keycode.h>
#include <SDL2/SDL_pixels.h>
#include <SDL2/SDL_render.h>
#include <SDL2/SDL_timer.h>
#include <SDL2/SDL_video.h>

#include <memory.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

const int WINDOW_WIDTH = 960;
const int WINDOW_HEIGHT = 720;
const int INTERNAL_WIDTH = 320;
const int INTERNAL_HEIGHT = 240;
const int FRAMEBUFFER_PIXELS = INTERNAL_WIDTH * INTERNAL_HEIGHT;
const int FRAMEBUFFER_BYTES = 2 * FRAMEBUFFER_PIXELS;
const int SYSTEM_CLOCK_FREQUENCY = 100 * 1000 * 1000;

struct perf_counters_t {
  uint64_t cycle;
  uint64_t framebuffer_writes;
};
struct clear_t {
  struct perf_counters_t counters;
  uint16_t color;
  int x;
  int y;
  bool active;
};

// Triangle with screen-space coordinates
struct screen_triangle_t {
  int16_t x0, y0;
  int16_t x1, y1;
  int16_t x2, y2;
};

struct triangle_rasterizer_t {
  struct screen_triangle_t triangle;
  struct screen_triangle_t deltas;
  int32_t e0, e1, e2;
  int16_t cursor_x, cursor_y;
  bool forward_traversal;
  bool found_edge;
  bool new_line;
  bool previous_e;
  int16_t max_y;
  uint16_t color;

  struct perf_counters_t counters;
  bool active;
};

struct gpu_t {
  uint16_t *framebuffer;
  uint16_t *debug_framebuffer;
  struct clear_t clear;
  struct triangle_rasterizer_t rasterizer;
  struct perf_counters_t counters;
};

void gpu_init(struct gpu_t *gpu);
void gpu_run_cycle(struct gpu_t *gpu);
void gpu_triangle_cycle(struct gpu_t *gpu,
                        struct triangle_rasterizer_t *rasterizer);
void gpu_framebuffer_write(struct gpu_t *gpu, int x, int y, uint16_t color);
void gpu_framebuffer_debug_write(struct gpu_t *gpu, int x, int y);
void gpu_start_clear(struct gpu_t *gpu, uint16_t color);
void gpu_draw_triangle(struct gpu_t *gpu, struct screen_triangle_t *triangle,
                       uint16_t color);
void gpu_report_duration(struct gpu_t *gpu, const char *message,
                         struct perf_counters_t *snapshot);

uint16_t rgb565(uint8_t r, uint8_t g, uint8_t b);
void rgb565_to_rgb888(uint16_t color, uint8_t *out);

void gpu_init(struct gpu_t *gpu) {
  gpu->framebuffer = malloc(FRAMEBUFFER_BYTES);
  gpu->debug_framebuffer = malloc(FRAMEBUFFER_BYTES);

  bzero(gpu->debug_framebuffer, FRAMEBUFFER_BYTES);
  for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
    for (int x = 0; x < INTERNAL_WIDTH; ++x) {
      gpu->framebuffer[y * INTERNAL_WIDTH + x] = rgb565(40, 40, 40);
    }
  }

  gpu->counters.cycle = 0;

  gpu->clear.active = false;
  gpu->rasterizer.active = false;
}

void gpu_run_cycle(struct gpu_t *gpu) {
  gpu->counters.cycle += 1;
  if (gpu->clear.active) {
    gpu_framebuffer_write(gpu, gpu->clear.x, gpu->clear.y, gpu->clear.color);
    if (gpu->clear.x == INTERNAL_WIDTH - 1) {
      gpu->clear.x = 0;
      if (gpu->clear.y == INTERNAL_HEIGHT - 1) {
        gpu->clear.active = false;
        gpu_report_duration(gpu, "clear", &gpu->clear.counters);
      } else {
        gpu->clear.y += 1;
      }
    } else {
      gpu->clear.x += 1;
    }
  }
  gpu_triangle_cycle(gpu, &gpu->rasterizer);
}

// Algorithm based on:
//   Pineda, Juan "A Parallel Algorithm for Polygon Rasterization"
//   Computer Graphics, Volume 22, Number 4, August 1988
void gpu_triangle_cycle(struct gpu_t *gpu,
                        struct triangle_rasterizer_t *rasterizer) {
  if (!rasterizer->active) {
    return;
  }
  gpu_framebuffer_debug_write(gpu, rasterizer->cursor_x, rasterizer->cursor_y);

  bool advance_x = false;
  bool advance_y = false;
  bool current_e =
      (rasterizer->e0 >= 0 && rasterizer->e1 >= 0 && rasterizer->e2 >= 0);
  bool draw_here = false;

  if (!rasterizer->found_edge) {
    bool moved_outside =
        !current_e && rasterizer->previous_e && !rasterizer->new_line;
    bool moved_inside =
        current_e && !rasterizer->previous_e && !rasterizer->new_line;
    if (moved_outside || moved_inside) {
      rasterizer->found_edge = true;

      // If we just left the triangle, turn around
      if (!current_e) {
        rasterizer->forward_traversal = !rasterizer->forward_traversal;
      }
      draw_here = current_e;
    }
    advance_x = true;
    advance_y = false;
  } else {
    // outside - we've found the second edge
    if (!current_e) {
      advance_x = false;
      advance_y = true;
    } else {
      // inside - keep drawing
      advance_x = true;
      advance_y = false;
    }
    draw_here = current_e;
  }
  if (draw_here) {
    gpu_framebuffer_write(gpu, rasterizer->cursor_x, rasterizer->cursor_y,
                          rasterizer->color);
  }
  SDL_LogDebug(SDL_LOG_CATEGORY_APPLICATION, "triangle cycle at %d,%d",
               rasterizer->cursor_x, rasterizer->cursor_y);
  SDL_LogDebug(SDL_LOG_CATEGORY_APPLICATION,
               "draw=%d current_e=%d advance_x=%d advance_y=%d "
               "found_edge=%d",
               draw_here, current_e, advance_x, advance_y,
               rasterizer->found_edge);
  SDL_LogDebug(SDL_LOG_CATEGORY_APPLICATION,
               "e0=%" PRIi32 " e1=%" PRIi32 " e2=%" PRIi32, rasterizer->e0,
               rasterizer->e1, rasterizer->e2);
  if (advance_x) {
    rasterizer->new_line = false;
    if (rasterizer->forward_traversal) {
      rasterizer->e0 += rasterizer->deltas.y0;
      rasterizer->e1 += rasterizer->deltas.y1;
      rasterizer->e2 += rasterizer->deltas.y2;
      rasterizer->cursor_x += 1;
    } else {
      rasterizer->e0 -= rasterizer->deltas.y0;
      rasterizer->e1 -= rasterizer->deltas.y1;
      rasterizer->e2 -= rasterizer->deltas.y2;
      rasterizer->cursor_x -= 1;
    }
  }
  if (advance_y) {
    rasterizer->found_edge = false;
    rasterizer->new_line = true;
    rasterizer->forward_traversal = !rasterizer->forward_traversal;
    if (rasterizer->cursor_y == rasterizer->max_y) {
      rasterizer->active = false;
      gpu_report_duration(gpu, "rasterizer", &rasterizer->counters);
    } else {
      rasterizer->e0 -= rasterizer->deltas.x0;
      rasterizer->e1 -= rasterizer->deltas.x1;
      rasterizer->e2 -= rasterizer->deltas.x2;
      rasterizer->cursor_y += 1;
    }
  }
  rasterizer->previous_e = current_e;
}

void gpu_framebuffer_write(struct gpu_t *gpu, int x, int y, uint16_t color) {
  gpu->framebuffer[y * INTERNAL_WIDTH + x] = color;
  gpu->counters.framebuffer_writes += 1;
}
void gpu_framebuffer_debug_write(struct gpu_t *gpu, int x, int y) {
  gpu->debug_framebuffer[y * INTERNAL_WIDTH + x] = rgb565(64, 200, 0);
}

void gpu_start_clear(struct gpu_t *gpu, uint16_t color) {
  gpu->clear.x = 0;
  gpu->clear.y = 0;
  gpu->clear.color = color;
  gpu->clear.active = true;
  gpu->clear.counters = gpu->counters;
}

void gpu_draw_triangle(struct gpu_t *gpu, struct screen_triangle_t *triangle,
                       uint16_t color) {
  struct triangle_rasterizer_t *rasterizer = &gpu->rasterizer;
  rasterizer->triangle = *triangle;
  rasterizer->active = true;
  rasterizer->color = color;

  rasterizer->deltas.x0 = triangle->x0 - triangle->x2;
  rasterizer->deltas.x1 = triangle->x1 - triangle->x0;
  rasterizer->deltas.x2 = triangle->x2 - triangle->x1;

  rasterizer->deltas.y0 = triangle->y0 - triangle->y2;
  rasterizer->deltas.y1 = triangle->y1 - triangle->y0;
  rasterizer->deltas.y2 = triangle->y2 - triangle->y1;

  rasterizer->cursor_x = triangle->x0;
  rasterizer->cursor_y = triangle->y0;

  if (triangle->y1 < rasterizer->cursor_y) {
    rasterizer->cursor_x = triangle->x1;
    rasterizer->cursor_y = triangle->y1;
  }
  if (triangle->y2 < rasterizer->cursor_y) {
    rasterizer->cursor_x = triangle->x2;
    rasterizer->cursor_y = triangle->y2;
  }

  rasterizer->max_y = triangle->y0;
  if (triangle->y1 > rasterizer->max_y) {
    rasterizer->max_y = triangle->y1;
  }
  if (triangle->y2 > rasterizer->max_y) {
    rasterizer->max_y = triangle->y2;
  }

  // TODO: model these multiplies, they will take up cycles
  rasterizer->e0 =
      ((int32_t)(rasterizer->cursor_x - triangle->x0)) * rasterizer->deltas.y0 -
      ((int32_t)(rasterizer->cursor_y - triangle->y0)) * rasterizer->deltas.x0;
  rasterizer->e1 =
      ((int32_t)(rasterizer->cursor_x - triangle->x1)) * rasterizer->deltas.y1 -
      ((int32_t)(rasterizer->cursor_y - triangle->y1)) * rasterizer->deltas.x1;
  rasterizer->e2 =
      ((int32_t)(rasterizer->cursor_x - triangle->x2)) * rasterizer->deltas.y2 -
      ((int32_t)(rasterizer->cursor_y - triangle->y2)) * rasterizer->deltas.x2;

  rasterizer->forward_traversal = true;
  // If we start "inside", we must be starting at a min point
  // maybe it is cleaner to just check if our cursor matches a point
  rasterizer->found_edge =
      rasterizer->e0 >= 0 && rasterizer->e1 >= 0 && rasterizer->e2 >= 0;
  rasterizer->previous_e = rasterizer->found_edge;

  rasterizer->counters = gpu->counters;

  SDL_LogDebug(SDL_LOG_CATEGORY_APPLICATION, "triangle start at %d,%d",
               rasterizer->cursor_x, rasterizer->cursor_y);
  SDL_LogDebug(SDL_LOG_CATEGORY_APPLICATION,
               "d0=%" PRIi32 ",%" PRIi32 " d1=%" PRIi32 ",%" PRIi32
               " d2=%" PRIi32 ",%" PRIi32,
               rasterizer->deltas.x0, rasterizer->deltas.y0,
               rasterizer->deltas.x1, rasterizer->deltas.y1,
               rasterizer->deltas.x2, rasterizer->deltas.y2);
}

void gpu_report_duration(struct gpu_t *gpu, const char *message,
                         struct perf_counters_t *snapshot) {
  uint64_t cycles = gpu->counters.cycle - snapshot->cycle;
  double us = (double)(cycles) * 1000000.0 / (double)(SYSTEM_CLOCK_FREQUENCY);
  double percentage = us / 16666.66 * 100;
  SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
              "%s took %" PRIu64 " cycles (%f us; %f %% of 60Hz frame)\n",
              message, cycles, us, percentage);
  uint64_t framebuffer_writes =
      gpu->counters.framebuffer_writes - snapshot->framebuffer_writes;
  percentage = (double)(framebuffer_writes) / (double)(cycles) * 100;
  SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
              "Framebuffer memory bandwidth utilization: %f%%\n", percentage);
}

void gpu_save_snapshot(struct gpu_t *gpu) {
  uint8_t *data = malloc(3 * FRAMEBUFFER_PIXELS);
  uint8_t *cursor = data;
  for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
    for (int x = 0; x < INTERNAL_WIDTH; ++x) {
      uint16_t color = gpu->framebuffer[y * INTERNAL_WIDTH + x];
      rgb565_to_rgb888(color, cursor);
      cursor += 3;
    }
  }
  stbi_write_png("build/snapshot.png", INTERNAL_WIDTH, INTERNAL_HEIGHT, 3, data,
                 3 * INTERNAL_WIDTH);
  free(data);
}

uint16_t rgb565(uint8_t r, uint8_t g, uint8_t b) {
  return ((r & 0b11111000) << 8) | ((g & 0b11111100) << 3) |
         ((b & 0b11111000) >> 3);
}

void rgb565_to_rgb888(uint16_t color, uint8_t *out) {
  uint8_t r = (color >> 8) & 0b11111000;
  uint8_t g = (color >> 3) & 0b11111100;
  uint8_t b = (color << 3) & 0b11111000;
  out[0] = r;
  out[1] = g;
  out[2] = b;
}

struct screen_triangle_t test_triangle1 = {
    .x0 = 160,
    .y0 = 25,
    .x1 = 25,
    .y1 = 215,
    .x2 = 295,
    .y2 = 120,
};
struct screen_triangle_t test_triangle2 = {
    .x0 = 25,
    .y0 = 25,
    .x1 = 25,
    .y1 = 100,
    .x2 = 100,
    .y2 = 100,
};
struct screen_triangle_t test_triangle3 = {
    .x0 = 100,
    .y0 = 25,
    .x1 = 25,
    .y1 = 100,
    .x2 = 175,
    .y2 = 100,
};
struct screen_triangle_t test_triangle4 = {
    .x0 = 100,
    .y0 = 25,
    .x1 = 25,
    .y1 = 25,
    .x2 = 35,
    .y2 = 100,
};

int main(int argc, char **argv) {
  if (SDL_Init(SDL_INIT_EVENTS | SDL_INIT_VIDEO) != 0) {
    printf("SDL_Init failed: %s", SDL_GetError());
    return 1;
  }
  SDL_LogSetPriority(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_DEBUG);

  SDL_Window *window = SDL_CreateWindow(
      "render", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WINDOW_WIDTH,
      WINDOW_HEIGHT, SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_MAXIMIZED);
  if (window == NULL) {
    printf("SDL_CreateWindow failed: %s", SDL_GetError());
    return 1;
  }

  SDL_Renderer *renderer =
      SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
  if (renderer == NULL) {
    printf("SDL_CreateRenderer failed: %s", SDL_GetError());
    return 1;
  }

  if (SDL_RenderSetLogicalSize(renderer, INTERNAL_WIDTH, INTERNAL_HEIGHT) !=
      0) {
    printf("SDL_RenderSetLogicalSize failed %s", SDL_GetError());
    return 1;
  }
  SDL_Texture *framebuffer_texture = SDL_CreateTexture(
      renderer, SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING,
      INTERNAL_WIDTH, INTERNAL_HEIGHT);
  if (framebuffer_texture == NULL) {
    printf("SDL_CreateTexture failed: %s", SDL_GetError());
    return 1;
  }

  SDL_SetRenderDrawColor(renderer, 255, 0, 255, 255);

  struct gpu_t gpu;
  gpu_init(&gpu);
  SDL_Rect screen_rect;
  screen_rect.x = 0;
  screen_rect.y = 0;
  screen_rect.h = INTERNAL_HEIGHT;
  screen_rect.w = INTERNAL_WIDTH;

  gpu_draw_triangle(&gpu, &test_triangle1, rgb565(255, 128, 0));

  bool end = false;
  bool new_frame = true;
  bool show_debug = false;

  while (!end) {
    SDL_Event event;
    while (SDL_PollEvent(&event) != 0) {
      if (event.type == SDL_QUIT) {
        end = true;
      }
      if (event.type == SDL_KEYDOWN) {
        switch (event.key.keysym.sym) {
        case SDLK_ESCAPE:
          end = true;
          break;
        case SDLK_p:
          gpu_save_snapshot(&gpu);
          break;
        case SDLK_s:
          if (event.key.keysym.mod & KMOD_SHIFT) {
            for (int i = 0; i < 1000; ++i) {
              gpu_run_cycle(&gpu);
            }
          } else {
            gpu_run_cycle(&gpu);
          }
          new_frame = true;
          break;
        case SDLK_d:
          show_debug = !show_debug;
          new_frame = true;
          break;
        default:
          break;
        }
      }
    }

    if (new_frame) {
      uint16_t *texture_memory = NULL;
      int _unused;
      SDL_LockTexture(framebuffer_texture, NULL, (void **)&texture_memory,
                      &_unused);
      memcpy(texture_memory, gpu.framebuffer, FRAMEBUFFER_BYTES);
      if (show_debug) {
        for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
          for (int x = 0; x < INTERNAL_WIDTH; ++x) {
            int index = y * INTERNAL_WIDTH + x;
            uint16_t value = gpu.debug_framebuffer[index];
            if (value != 0) {
              texture_memory[index] = value;
            }
          }
        }
      }
      SDL_UnlockTexture(framebuffer_texture);

      SDL_RenderClear(renderer);
      SDL_RenderCopy(renderer, framebuffer_texture, &screen_rect, &screen_rect);
      SDL_RenderPresent(renderer);
      new_frame = false;
    } else {
      SDL_Delay(16);
    }
  }

  SDL_Quit();
  return 0;
}
