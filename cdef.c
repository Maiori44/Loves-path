typedef struct gameobject {
	const int quads;
	uint8_t hp, x, y, direction, var1;
	bool var2;
	const uint8_t key;
	uint8_t frame;
	float momx, momy;
	const char *sprite, *quadtype, *type;
	char lastaxis[2];
} gameobject;

typedef struct playerobject {
	struct gameobject;
	uint8_t ftime;
	float fmomx, fmomy;
	uint8_t bosskey;
} playerobject;