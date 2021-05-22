#define ALARM_TRIGGER_COUNT 10

#include "BcastMap.h"

bcast_map_t* createMapEl(uint16_t sender_id, uint8_t counter) {
	bcast_map_t* el = (bcast_map_t*)malloc(sizeof(bcast_map_t));

	// malloc fail, abort
	if (el == NULL) {
		exit(-1);
	}
	el->sender_id = sender_id;
	el->last_counter = counter;
	el->consecutive_counter = 1;
	el->next = NULL;

	return el;
}

bcast_map_t* findById(bcast_map_t *l, uint16_t id) {
	while (l != NULL && l->sender_id != id) {
		l = l->next;
	}

	return l;
}

/*
	Return true if there is the necessity to send an alarm message, false otherwise
*/
bool updateBcastMap(bcast_map_t **l, uint16_t sender_id, uint8_t counter) {
	bcast_map_t *el = findById(*l, sender_id);

	// id not present in map, insert a new element in the map
	if (el == NULL) {
		el = createMapEl(sender_id, counter);
		el->next = *l;
		*l = el;
	
		return FALSE;
	}
	// update the already existing element
	else {
		// a consecutive message is received
		if (el->last_counter == counter - 1) {
			el->last_counter = counter;
			el->consecutive_counter++;
		
			// check if enough consecuive messages for an alarm have been received
			if (el->consecutive_counter >= ALARM_TRIGGER_COUNT) {
				// reset counter
				el->consecutive_counter = 0;
				return TRUE;
			}
			else {
				return FALSE;
			}
		}
		// non consecutive message case
		else {
			el->last_counter = counter;
			el->consecutive_counter = 1;
			return FALSE;
		}
	}
}

