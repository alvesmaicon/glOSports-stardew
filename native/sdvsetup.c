// The screen of Stardew Valley's first start, while import.sh gets the player's game ready (SDV_UI=1): it draws the
// lines import.sh writes, each led by its kind: T the title, U the line under it, S a step (the step before it is
// done), I a note, E an error, D the end, W a prompt that waits for a button; G the seconds each step after it takes,
// P "<done> <total>" of the step running, R the time left's two formats ("about %d min|under a minute"), for the
// progress bar. It ends with its input, after the prompt's button when there is one. Without a screen it copies its
// input to stdout, so the import never stops.
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
        if (!buf[0] || buf[1] != ' ' || !strchr("TUSIEDWGPR", buf[0]))
            continue;
        SDL_LockMutex(lock);
        // a step's progress replaces its last one; when full, the oldest step line goes, never T, U, R or G
        if (buf[0] == 'P' && nlines && lines[nlines - 1].kind == 'P')
            nlines--;
        if (nlines == MAXL) {
            int old = 0;
            while (old < nlines - 1 && strchr("TURG", lines[old].kind))
                old++;
            memmove(lines + old, lines + old + 1, sizeof(Line) * (nlines - old - 1));
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

// the share of the work done (0-1) and the seconds left, from the last G line's estimates: steps done count whole,
// the running one by its P lines, or by its time against its estimate (95% at most); -1 without a G line
static float progress(int *left)
{
    int g = -1;
    for (int i = 0; i < nlines; i++)
        if (lines[i].kind == 'G')
            g = i;
    if (g < 0)
        return -1;
    float est[16], total = 0, done = 0, rest = 0;
    int n = 0, k = 0;
    for (char *p = lines[g].text, *e; n < 16; p = e) {
        float v = strtof(p, &e);
        if (e == p)
            break;
        est[n++] = v > 1 ? v : 1;
        total += v > 1 ? v : 1;
    }
    for (int i = g + 1; i < nlines && k < n; i++) {
        if (lines[i].kind == 'D')
            done = total, rest = 0, k = n;
        if (lines[i].kind != 'S')
            continue;
        Uint32 end;
        char how = step_end(i, &end);
        if (how) {
            done += est[k++];
            continue;
        }
        float f = -1;
        for (int j = i + 1; j < nlines; j++) {
            unsigned a, b;
            if (lines[j].kind == 'P' && sscanf(lines[j].text, "%u %u", &a, &b) == 2 && b)
                f = (float)a / b;
        }
        if (f < 0) {
            f = (end - lines[i].at) / 1000.0f / est[k];
            if (f > 0.95f)
                f = 0.95f;
        }
        if (f > 1)
            f = 1;
        done += est[k] * f;
        rest += est[k] * (1 - f);
        while (++k < n)
            rest += est[k];
    }
    while (k < n)
        rest += est[k++];
    *left = (int)rest;
    return total > 0 ? done / total : 0;
}

// the running step's own P share, or -1
static int step_percent(int i)
{
    int pct = -1;
    for (int j = i + 1; j < nlines && !strchr("SED", lines[j].kind); j++) {
        unsigned a, b;
        if (lines[j].kind == 'P' && sscanf(lines[j].text, "%u %u", &a, &b) == 2 && b)
            pct = a >= b ? 100 : (int)(100.0 * a / b);
    }
    return pct;
}

static void draw(SDL_Texture *sky, int waiting)
{
    static const SDL_Color white = {255, 255, 255, 255}, soft = {214, 226, 240, 255}, green = {150, 236, 128, 255},
                           red = {255, 150, 140, 255}, gold = {255, 222, 120, 255};
    static const char *spin[] = {".", "..", "...", ""};
    char buf[256];
    int y = 28, panel = 132, left = 0, failed = 0;
    SDL_RenderCopy(ren, sky, NULL, NULL);
    for (int i = 0; i < nlines; i++) {
        if (lines[i].kind == 'T')
            y += text(big, lines[i].text, -1, y, white, 0) + 4;
        else if (lines[i].kind == 'U')
            y += text(mid, lines[i].text, -1, y, gold, 0);
    }
    SDL_SetRenderDrawBlendMode(ren, SDL_BLENDMODE_BLEND);
    float share = progress(&left);
    if (share >= 0) {
        const char *about = "about %d min left", *under = "under a minute left";
        static char fmt[2][160];
        for (int i = 0; i < nlines; i++) {
            char *bar;
            failed |= lines[i].kind == 'E';
            if (lines[i].kind != 'R' || !(bar = strchr(lines[i].text, '|')))
                continue;
            // the format may hold one %d and no other conversion
            char *pc = strchr(lines[i].text, '%'), *more = pc ? strchr(pc + 1, '%') : NULL;
            if (!pc || pc > bar || pc[1] != 'd' || (more && more < bar))
                continue;
            snprintf(fmt[0], sizeof fmt[0], "%.*s", (int)(bar - lines[i].text), lines[i].text);
            snprintf(fmt[1], sizeof fmt[1], "%s", bar + 1);
            about = fmt[0];
            under = fmt[1];
        }
        SDL_Rect back = {44, y + 8, W - 88, 14}, fill = back;
        fill.w = (int)(back.w * share);
        SDL_SetRenderDrawColor(ren, 16, 28, 52, 170);
        SDL_RenderFillRect(ren, &back);
        SDL_SetRenderDrawColor(ren, failed ? 220 : share >= 1 ? 120 : 255, failed ? 96 : share >= 1 ? 210 : 214,
                               failed ? 88 : share >= 1 ? 100 : 96, 255);
        SDL_RenderFillRect(ren, &fill);
        int n = snprintf(buf, sizeof buf, "%d%%", (int)(share * 100 + 0.5f));
        if (!failed && share < 1) {
            snprintf(buf + n, sizeof buf - n, "  ·  ");
            n = strlen(buf);
            if (left >= 60)
                snprintf(buf + n, sizeof buf - n, about, (left + 59) / 60);
            else
                snprintf(buf + n, sizeof buf - n, "%s", under);
        }
        text(small, buf, -1, y + 26, soft, 0);
        panel = y + 66;
    }
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
            int pct = how ? -1 : step_percent(i);
            text(mid, how == 'E' ? "X" : how ? "OK" : spin[(SDL_GetTicks() / 500) % 4], 44, y,
                 how == 'E' ? red : how ? green : gold, 0);
            int h = text(mid, l->text, 100, y, white, 430);
            if (pct >= 0)
                snprintf(buf, sizeof buf, "%d%%", pct);
            else
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
