#ifndef KEEPYOURDISTANCE_H
#define KEEPYOURDISTANCE_H

typedef nx_struct radio_id_msg {
  nx_uint16_t sender_id;
  nx_uint8_t counter;
} radio_id_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 6,
};

//------------------------------------
typedef struct bcast_map bcast_map_t;

struct bcast_map {
  uint16_t sender_id;
  uint8_t last_counter;
  uint8_t consecutive_counter;
  bcast_map_t *next;
};

//-----------------------------------

#endif
