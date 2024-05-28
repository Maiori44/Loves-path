typedef struct gameobject {
	const double quads;
	const uint8_t key;
	const char *sprite, *quadtype, *type;
	uint8_t hp, x, y, direction, var1, frame;
	bool var2, lastaxis;
	float momx, momy;
} gameobject;

typedef struct playerobject {
	struct gameobject;
	uint8_t ftime, bosskey;
	float fmomx, fmomy;
} playerobject;