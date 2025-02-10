#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb_image_write.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_error.h>
#include <SDL2/SDL_keycode.h>
#include <SDL2/SDL_log.h>
#include <SDL2/SDL_pixels.h>
#include <SDL2/SDL_render.h>
#include <SDL2/SDL_timer.h>
#include <SDL2/SDL_video.h>

#include <memory.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

const int WINDOW_WIDTH = 960;
const int WINDOW_HEIGHT = 720;
const int INTERNAL_WIDTH = 320;
const int INTERNAL_HEIGHT = 240;
const int FRAMEBUFFER_PIXELS = INTERNAL_WIDTH * INTERNAL_HEIGHT;
const int FRAMEBUFFER_BYTES = 2 * FRAMEBUFFER_PIXELS;
const int SRAM_BYTES = 2 * 1024 * 1024;

#define CMD_NONE 0
#define CMD_STEP_ONE 1
#define CMD_STEP_MANY 2
#define CMD_FINISH 3

struct rams_t {
  uint16_t *sram;
};

struct rams_t *gpu;
SDL_Renderer *renderer;
SDL_Texture *framebuffer_texture;

int ghdl_main(int argc, char **argv);
uint16_t rgb565(uint8_t r, uint8_t g, uint8_t b);
void rgb565_to_rgb888(uint16_t color, uint8_t *out);

void system_init(void) {
  gpu = malloc(sizeof(struct rams_t));

  gpu->sram = malloc(SRAM_BYTES);

  uint16_t *framebuffer = gpu->sram;
  for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
    for (int x = 0; x < INTERNAL_WIDTH; ++x) {
      framebuffer[y * INTERNAL_WIDTH + x] = rgb565(40, 40, 40);
    }
  }
}

void sim_sram_write16(int word_address, int value) {
  gpu->sram[word_address] = (uint16_t)(value);

  uint16_t *texture_memory = NULL;
  int _unused;
  SDL_LockTexture(framebuffer_texture, NULL, (void **)&texture_memory,
                  &_unused);
  memcpy(texture_memory, gpu->sram, FRAMEBUFFER_BYTES);
  SDL_UnlockTexture(framebuffer_texture);

  SDL_RenderClear(renderer);
  SDL_Rect screen_rect;
  screen_rect.x = 0;
  screen_rect.y = 0;
  screen_rect.h = INTERNAL_HEIGHT;
  screen_rect.w = INTERNAL_WIDTH;
  SDL_RenderCopy(renderer, framebuffer_texture, &screen_rect, &screen_rect);
  SDL_RenderPresent(renderer);
}

void gpu_save_snapshot(void) {
  uint8_t *data = malloc(3 * FRAMEBUFFER_PIXELS);
  uint8_t *cursor = data;
  for (int y = 0; y < INTERNAL_HEIGHT; ++y) {
    for (int x = 0; x < INTERNAL_WIDTH; ++x) {
      uint16_t color = gpu->sram[y * INTERNAL_WIDTH + x];
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

int handle_event(void) {
  SDL_Event event;
  if (SDL_PollEvent(&event) == 0) {
    return CMD_NONE;
  }
  if (event.type == SDL_QUIT) {
    return CMD_FINISH;
  }
  if (event.type == SDL_KEYDOWN) {
    switch (event.key.keysym.sym) {
    case SDLK_ESCAPE:
      return CMD_FINISH;
    case SDLK_p:
      gpu_save_snapshot();
      return CMD_NONE;
    case SDLK_s:
      if (event.key.keysym.mod & KMOD_SHIFT) {
        return CMD_STEP_MANY;
      } else {
        return CMD_STEP_ONE;
      }
    }
  }
  return CMD_NONE;
}

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

  renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
  if (renderer == NULL) {
    printf("SDL_CreateRenderer failed: %s", SDL_GetError());
    return 1;
  }

  if (SDL_RenderSetLogicalSize(renderer, INTERNAL_WIDTH, INTERNAL_HEIGHT) !=
      0) {
    printf("SDL_RenderSetLogicalSize failed %s", SDL_GetError());
    return 1;
  }
  framebuffer_texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGB565,
                                          SDL_TEXTUREACCESS_STREAMING,
                                          INTERNAL_WIDTH, INTERNAL_HEIGHT);
  if (framebuffer_texture == NULL) {
    printf("SDL_CreateTexture failed: %s", SDL_GetError());
    return 1;
  }

  SDL_SetRenderDrawColor(renderer, 255, 0, 255, 255);

  system_init();

  return ghdl_main(argc, argv);
}
