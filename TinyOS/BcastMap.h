#ifndef BCASTMAP_H
#define BCASTMAP_H

typedef struct bcast_map bcast_map_t;

struct bcast_map {
  uint16_t sender_id;
  uint8_t last_counter;
  uint8_t consecutive_counter;
  bcast_map_t *next;
};

bcast_map_t* createMapEl(uint16_t sender_id, uint8_t counter);

bcast_map_t* findById(bcast_map_t *l, uint16_t id);

bool updateBcastMap(bcast_map_t **l, uint16_t sender_id, uint8_t counter);

#endif

