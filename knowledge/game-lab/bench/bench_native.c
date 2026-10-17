/* bench_native.c — game-lab native training bench.
 *
 * Purpose: a tiny deterministic "fake game" for offline lab work:
 *  - keeps a global GameState with known struct layout,
 *  - damages the player on a timer (auto mode),
 *  - prints its state and struct pattern bytes for external tools,
 *  - prints its own module base + the VA of apply_damage for static/dynamic mapping.
 *
 * Build: build_bench.bat (MSVC x64). No CRT-specific flags. Console subsystem.
 *
 * Struct layout (sizeof(GameState)=0x38=56 on x64 MSVC /Zp8 default, measured):
 *   float health;   offset 0x00
 *   int   ammo;     offset 0x04
 *   char  name[24]; offset 0x08
 *   int   xp;       offset 0x20
 *   long  calls;    offset 0x24   (long is 4 bytes on x64 Windows)
 *   double score;   offset 0x28
 *   int   keep;     offset 0x30
 *   (no trailing pad beyond 0x38; max alignment 8 -> size=0x38)
 */
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

typedef struct GameState {
    float  health;
    int    ammo;
    char   name[24];
    int    xp;
    long   calls;
    double score;
    int    keep;
} GameState;              /* total 64 bytes = 0x40 on x64 */

static GameState g = { 100.0f, 25, "bench_warrior", 0, 0, 999.5, 0 };

static void apply_damage(GameState* p, float dmg)
{
    p->health -= dmg;
    if (p->health <= 0.0f) p->health = 0.0f;
    p->calls++;
    if (p->xp + 10 < 2000000) p->xp += 10;
}

static void hexprint(const char* tag, const void* pv, int n)
{
    const unsigned char* p = (const unsigned char*)pv;
    int i;
    printf("%s=", tag);
    for (i = 0; i < n; ++i) printf("%02x", p[i]);
    printf("\n");
}

int main(int argc, char** argv)
{
    int rounds = 5;                 /* background timer tear of health */
    int i, quit = 0;
    int hold_ms = 0;                /* --hold: stay at initial state N ms */
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--rounds") == 0 && i + 1 < argc) rounds = atoi(argv[i + 1]);
        else if (strcmp(argv[i], "--once") == 0) rounds = 1;
        else if (strcmp(argv[i], "--hold") == 0 && i + 1 < argc) hold_ms = atoi(argv[i + 1]);
    }

    printf("bench_native pid-seeking via external process list.\n");
    printf("struct GameState size=%zu\n", sizeof(GameState));
    printf("hdr_module_base=%p\n", (void*)GetModuleHandleW(NULL));
    printf("hdr_apply_damage=%p\n", (void*)&apply_damage);
    printf("hdr_g=%p\n", (void*)&g);
    printf("offsets: health=0x%zx ammo=0x%zx name=0x%zx xp=0x%zx calls=0x%zx score=0x%zx\n",
        offsetof(GameState, health), offsetof(GameState, ammo),
        offsetof(GameState, name), offsetof(GameState, xp),
        offsetof(GameState, calls), offsetof(GameState, score));
    hexprint("hdr_g_aob", &g, (int)sizeof(GameState));
    /* stable-in-time AOB: bytes from offset 4 (ammo) to end of name (0x1F) —
     * 28 bytes that never change across ticks (both are init-only fields). */
    hexprint("hdr_g_aob_static", ((unsigned char*)&g) + 4, 28);
    if (hold_ms)
        Sleep(hold_ms);

    for (i = 0; i < rounds && !quit; ++i) {
        apply_damage(&g, 7.0f);            /* deterministic tick damage */
        printf("tick=%d health=%.2f ammo=%d xp=%d calls=%d score=%.2f\n",
            i + 1, g.health, g.ammo, g.xp, g.calls, g.score);
        fflush(stdout);
        Sleep(2000);
        if (argc > 1 && strcmp(argv[1], "--once") == 0) break;
        /* drain stdin non-blocking style: quit on 'q' line */
        /* console read is intentionally omitted; use taskkill to stop */
    }
    /* final state print for the last tick correlation */
    printf("final tick=%d health=%.2f calls=%d\n", rounds, g.health, g.calls);
    printf("ends\n");
    Sleep(8000);        /* give the external probe time to attach and read memory */
    printf("bye\n");
    return 0;
}
