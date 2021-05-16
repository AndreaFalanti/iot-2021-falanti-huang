#ifndef KEEPYOURDISTANCE_H
#define KEEPYOURDISTANCE_H

typedef nx_struct radio_id_msg {
  nx_uint16_t sender_id;
} radio_id_msg_t;

typedef nx_struct radio_alarm_msg {
  nx_uint16_t mote_id;
  nx_uint16_t proximity_mote_id;
} radio_alarm_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 6,
};

#endif
