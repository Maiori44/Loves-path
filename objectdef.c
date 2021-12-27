typedef struct gameobject {
    void *quads;
    uint8_t hp, x, y, direction;
    const int8_t key;
    float momx, momy;
    const char *sprite, *quadtype, *type;
    char lastaxis[2];
} gameobject;

typedef struct playerobject {
    struct gameobject;
    uint8_t ftime;
    float fmomx, fmomy;
} playerobject;