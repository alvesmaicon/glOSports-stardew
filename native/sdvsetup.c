// The screen of Stardew Valley's first start, while import.sh gets the player's game ready (SDV_UI=1): it draws the
// lines import.sh writes, each led by its kind: T the title, U the line under it, S a step (the step before it is
// done), I a note, E an error, D the end, W a prompt that waits for a button. It ends with its input, after the
// prompt's button when there is one. Without a screen it copies its input to stdout, so the import never stops.
//   SDV_UI=1 sh import.sh | sdvsetup <font.ttf>       exits 1 after an error; SDVSETUP_SHOT=<bmp> saves the last frame
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define W 640
#define H 480
#define MAXL 48

typedef struct { char kind; char text[400]; Uint32 at; int h; } Line;

static Line lines[MAXL];
static int nlines;
static int input_done, changed = 1;
static SDL_mutex *lock;

static int reader(void *arg)
{
    char buf[400];
    (void)arg;
    while (fgets(buf, sizeof buf, stdin)) {
        buf[strcspn(buf, "\r\n")] = 0;
        printf("%s\n", buf);
        fflush(stdout);
        if (!buf[0] || buf[1] != ' ' || !strchr("TUSIEDW", buf[0]))
            continue;
        SDL_LockMutex(lock);
        if (nlines == MAXL) {
            memmove(lines, lines + 1, sizeof(Line) * (MAXL - 1));
            nlines--;
        }
        lines[nlines].kind = buf[0];
        snprintf(lines[nlines].text, sizeof lines[nlines].text, "%s", buf + 2);
        lines[nlines].at = SDL_GetTicks();
        lines[nlines].h = 0;
        nlines++;
        changed = 1;
        SDL_UnlockMutex(lock);
    }
    SDL_LockMutex(lock);
    input_done = changed = 1;
    SDL_UnlockMutex(lock);
    return 0;
}

// what follows step i: 'E' failed, 'S' or 'D' done (at that line's time), 0 still running
static char step_end(int i, Uint32 *end)
{
    for (int j = i + 1; j < nlines; j++)
        if (strchr("SED", lines[j].kind)) {
            *end = lines[j].at;
            return lines[j].kind == 'E' ? 'E' : 'S';
        }
    *end = SDL_GetTicks();
    return 0;
}

static TTF_Font *big, *mid, *small;
static SDL_Renderer *ren;

// text with a shadow at x (or centred, x < 0), wrapped to wrap px; returns its height
static int text(TTF_Font *f, const char *s, int x, int y, SDL_Color c, int wrap)
{
    SDL_Color shade = {20, 30, 50, 255};
    SDL_Surface *sf = wrap ? TTF_RenderUTF8_Blended_Wrapped(f, s, c, wrap) : TTF_RenderUTF8_Blended(f, s, c);
    SDL_Surface *sh = wrap ? TTF_RenderUTF8_Blended_Wrapped(f, s, shade, wrap) : TTF_RenderUTF8_Blended(f, s, shade);
    if (!sf || !sh) {
        SDL_FreeSurface(sf);
        SDL_FreeSurface(sh);
        return 0;
    }
    if (x < 0)
        x = (W - sf->w) / 2;
    SDL_Texture *t = SDL_CreateTextureFromSurface(ren, sh);
    SDL_Rect r = {x + 2, y + 2, sh->w, sh->h};
    SDL_RenderCopy(ren, t, NULL, &r);
    SDL_DestroyTexture(t);
    t = SDL_CreateTextureFromSurface(ren, sf);
    r.x = x;
    r.y = y;
    SDL_RenderCopy(ren, t, NULL, &r);
    SDL_DestroyTexture(t);
    int h = sf->h;
    SDL_FreeSurface(sf);
    SDL_FreeSurface(sh);
    return h;
}

// the height a line takes in the panel, measured once
static int height(Line *l)
{
    static const SDL_Color c = {255, 255, 255, 255};
    TTF_Font *f = l->kind == 'I' ? small : mid;
    int wrap = l->kind == 'S' ? 430 : l->kind == 'I' ? 480 : 552;
    if (!l->h) {
        SDL_Surface *s = TTF_RenderUTF8_Blended_Wrapped(f, l->text, c, wrap);
        l->h = (s ? s->h : 24) + (l->kind == 'E' || l->kind == 'D' ? 10 : 8);
        SDL_FreeSurface(s);
    }
    return l->h;
}

static void draw(SDL_Texture *sky, int waiting)
{
    static const SDL_Color white = {255, 255, 255, 255}, soft = {214, 226, 240, 255}, green = {150, 236, 128, 255},
                           red = {255, 150, 140, 255}, gold = {255, 222, 120, 255};
    static const char *spin[] = {".", "..", "...", ""};
    char buf[32];
    int y = 28, panel = 132;
    SDL_RenderCopy(ren, sky, NULL, NULL);
    for (int i = 0; i < nlines; i++) {
        if (lines[i].kind == 'T')
            y += text(big, lines[i].text, -1, y, white, 0) + 4;
        else if (lines[i].kind == 'U')
            y += text(mid, lines[i].text, -1, y, gold, 0);
    }
    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);
    SDL_SetRenderDrawColor(ren, 16, 28, 52, 150);
    SDL_Rect box = {28, panel - 12, W - 56, H - panel - 36};
    SDL_RenderFillRect(ren, &box);

    // the last lines that fit the panel
    int first = nlines, used = 0;
    for (int i = nlines - 1; i >= 0; i--) {
        if (!strchr("SIED", lines[i].kind))
            continue;
        used += height(&lines[i]);
        if (used > box.y + box.h - panel)
            break;
        first = i;
    }
    y = panel;
    for (int i = first; i < nlines; i++) {
        Line *l = &lines[i];
        if (l->kind == 'S') {
            Uint32 end;
            char how = step_end(i, &end);
            Uint32 s = (end - l->at) / 1000;
            text(mid, how == 'E' ? "X" : how ? "OK" : spin[(SDL_GetTicks() / 500) % 4], 44, y,
                 how == 'E' ? red : how ? green : gold, 0);
            int h = text(mid, l->text, 100, y, white, 430);
            snprintf(buf, sizeof buf, "%u:%02u", s / 60, s % 60);
            text(small, buf, 548, y + 4, soft, 0);
            y += h + 8;
        } else if (l->kind == 'I') {
            y += text(small, l->text, 100, y, soft, 480) + 8;
        } else if (l->kind == 'E') {
            y += text(mid, l->text, 44, y, red, 552) + 10;
        } else if (l->kind == 'D') {
            y += text(mid, l->text, 44, y, green, 552) + 10;
        }
    }
    for (int i = 0; i < nlines; i++)
        if (lines[i].kind == 'W' && waiting)
            text(small, lines[i].text, -1, H - 30, white, 0);
    SDL_RenderPresent(ren);
}

static SDL_Texture *make_sky(void)
{
    SDL_Surface *s = SDL_CreateRGBSurfaceWithFormat(0, W, H, 32, SDL_PIXELFORMAT_RGBA32);
    for (int y = 0; y < H; y++) {
        float t = (float)y / (H - 1);
        SDL_Rect r = {0, y, W, 1};
        SDL_FillRect(s, &r, SDL_MapRGB(s->format, 64 + t * 62, 120 + t * 66, 222 + t * 20));
    }
    SDL_Texture *t = SDL_CreateTextureFromSurface(ren, s);
    SDL_FreeSurface(s);
    return t;
}

static void save_shot(const char *path)
{
    SDL_Surface *s = SDL_CreateRGBSurfaceWithFormat(0, W, H, 32, SDL_PIXELFORMAT_ARGB8888);
    if (s && SDL_RenderReadPixels(ren, NULL, SDL_PIXELFORMAT_ARGB8888, s->pixels, s->pitch) == 0)
        SDL_SaveBMP(s, path);
    SDL_FreeSurface(s);
}

int main(int argc, char **argv)
{
    lock = SDL_CreateMutex();
    if (argc < 2 || SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) != 0 || TTF_Init() != 0 ||
            !(big = TTF_OpenFont(argv[1], 40)) || !(mid = TTF_OpenFont(argv[1], 24)) ||
            !(small = TTF_OpenFont(argv[1], 18))) {
        fprintf(stderr, "sdvsetup: no screen (%s): text only\n", SDL_GetError());
        reader(NULL);
        return 0;
    }
    SDL_Window *win = SDL_CreateWindow("Stardew Valley", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, W, H,
                                       SDL_WINDOW_FULLSCREEN);
    ren = win ? SDL_CreateRenderer(win, -1, 0) : NULL;
    if (!ren) {
        fprintf(stderr, "sdvsetup: no screen (%s): text only\n", SDL_GetError());
        reader(NULL);
        return 0;
    }
    SDL_RenderSetLogicalSize(ren, W, H);
    SDL_ShowCursor(SDL_DISABLE);
    for (int i = 0; i < SDL_NumJoysticks(); i++)
        SDL_JoystickOpen(i);
    SDL_Texture *sky = make_sky();
    SDL_DetachThread(SDL_CreateThread(reader, "reader", NULL));

    const char *shot = getenv("SDVSETUP_SHOT");
    Uint32 last = 0, prompt_at = 0;
    int failed = 0, done = 0;
    while (!done) {
        SDL_Event e;
        while (SDL_PollEvent(&e))
            if (prompt_at && SDL_GetTicks() - prompt_at > 400 &&
                    (e.type == SDL_JOYBUTTONDOWN || e.type == SDL_CONTROLLERBUTTONDOWN || e.type == SDL_KEYDOWN))
                done = 1;
        SDL_LockMutex(lock);
        int finished = input_done, prompt = 0;
        failed = 0;
        for (int i = 0; i < nlines; i++) {
            failed |= lines[i].kind == 'E';
            prompt |= lines[i].kind == 'W';
        }
        if (finished && prompt && !prompt_at)
            prompt_at = SDL_GetTicks();
        if (changed || SDL_GetTicks() - last >= 500) {
            draw(sky, finished && prompt);
            changed = 0;
            last = SDL_GetTicks();
        }
        SDL_UnlockMutex(lock);
        if (finished && (shot || !prompt)) {
            if (shot)
                save_shot(shot);
            done = 1;
        }
        SDL_Delay(50);
    }
    SDL_Quit();
    return failed;
}
