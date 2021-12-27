typedef struct gameobject {
	const int quads;
	uint8_t hp, x, y, direction;
	union {
		bool var;
		uint8_t var;
	};
	const int8_t key;
	float momx, momy;
	const char *sprite, *quadtype, *type;
	char lastaxis[2];
} gameobject;

typedef struct playerobject {
	struct gameobject;
	uint8_t ftime;
	float fmomx, fmomy;
	int8_t bosskey;
} playerobject;