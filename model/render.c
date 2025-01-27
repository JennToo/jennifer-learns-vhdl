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
const int FRAMEBUFFER_BYTES = 2 * INTERNAL_WIDTH * INTERNAL_HEIGHT;
const int SYSTEM_CLOCK_FREQUENCY = 100 * 1000 * 1000;

struct clear_t {
  uint64_t start_cycle;
  uint16_t color;
  int x;
  int y;
  bool active;
};

struct gpu_t {
  uint16_t *framebuffer;

  struct clear_t clear;

  uint64_t cycle_count;
  uint64_t framebuffer_writes;
};

void gpu_init(struct gpu_t *gpu);
void gpu_run_cycle(struct gpu_t *gpu);
void gpu_framebuffer_write(struct gpu_t *gpu, int x, int y, uint16_t color);
void gpu_start_clear(struct gpu_t *gpu, uint16_t color);
void gpu_report_duration(struct gpu_t *gpu, const char *message,
                         uint64_t start_cycle);

void gpu_init(struct gpu_t *gpu) {
  gpu->framebuffer = malloc(FRAMEBUFFER_BYTES);

  // Temporary pattern so I know the framebuffer is being draw correctly on the
  // screen
  for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
    for (int x = 0; x < INTERNAL_WIDTH; ++x) {
      if (((x + y) & 1) == 0) {
        gpu->framebuffer[y * INTERNAL_WIDTH + x] = 0xFFFF;
      } else {
        gpu->framebuffer[y * INTERNAL_WIDTH + x] = 0;
      }
    }
  }

  gpu->cycle_count = 0;

  gpu->clear.active = false;
}

void gpu_run_cycle(struct gpu_t *gpu) {
  gpu->cycle_count += 1;
  if (gpu->clear.active) {
    gpu_framebuffer_write(gpu, gpu->clear.x, gpu->clear.y, gpu->clear.color);
    if (gpu->clear.x == INTERNAL_WIDTH - 1) {
      gpu->clear.x = 0;
      if (gpu->clear.y == INTERNAL_HEIGHT - 1) {
        gpu->clear.active = false;
        gpu_report_duration(gpu, "clear", gpu->clear.start_cycle);
      } else {
        gpu->clear.y += 1;
      }
    } else {
      gpu->clear.x += 1;
    }
  }
}

void gpu_framebuffer_write(struct gpu_t *gpu, int x, int y, uint16_t color) {
  gpu->framebuffer[y * INTERNAL_WIDTH + x] = color;
  gpu->framebuffer_writes += 1;
}

void gpu_start_clear(struct gpu_t *gpu, uint16_t color) {
  gpu->clear.x = 0;
  gpu->clear.y = 0;
  gpu->clear.color = color;
  gpu->clear.active = true;
  gpu->clear.start_cycle = gpu->cycle_count;
}

void gpu_report_duration(struct gpu_t *gpu, const char *message,
                         uint64_t start_cycle) {
  uint64_t cycles = gpu->cycle_count - start_cycle;
  double us = (double)(cycles) * 1000000.0 / (double)(SYSTEM_CLOCK_FREQUENCY);
  double percentage = us / 16666.66 * 100;
  printf("%s took %" PRIu64 " cycles (%f us; %f %% of 60Hz frame)\n", message,
         cycles, us, percentage);
}

int main(int argc, char **argv) {
  if (SDL_Init(SDL_INIT_EVENTS | SDL_INIT_VIDEO) != 0) {
    printf("SDL_Init failed: %s", SDL_GetError());
    return 1;
  }

  SDL_Window *window =
      SDL_CreateWindow("render", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                       WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_ALLOW_HIGHDPI);
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

  gpu_start_clear(&gpu, 0x07F5);

  bool end = false;
  bool new_frame = true;
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
        default:
          break;
        }
      }
    }

    if (new_frame) {
      void *texture_memory = NULL;
      int _unused;
      SDL_LockTexture(framebuffer_texture, NULL, &texture_memory, &_unused);
      memcpy(texture_memory, gpu.framebuffer, FRAMEBUFFER_BYTES);
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
