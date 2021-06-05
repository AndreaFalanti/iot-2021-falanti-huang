#include "Timer.h"
#include "KeepYourDistance.h"

#include <stdio.h>
#include <stdarg.h>

#define FREQ 500
#define ALARM_TRIGGER_COUNT 10

module KeepYourDistanceC @safe() {
  uses {
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
    interface Packet;
  }
}


implementation {
    message_t packet;

    bool locked = FALSE;
    uint16_t counter = 0;
    
    bcast_map_t *map = NULL;
    
    // ----------------------------------------------------------------------
    
    /* Printf wrapper to have a similar format to TOSSIM debug function */
    void logMessage(char *debug_ch, char *fmt, ...) {
        char formatted_string[255];

        va_list argptr;
        va_start(argptr,fmt);
        vsprintf(formatted_string, fmt, argptr);
        va_end(argptr);

        printf("[%s] (ID: %u) %s\n", debug_ch, TOS_NODE_ID, formatted_string);
    }
    
    // ---------------------- MAP DATA STRUCTURE ----------------------------

	bcast_map_t* createMapEl(uint16_t sender_id, uint16_t msg_counter) {
		bcast_map_t* el = (bcast_map_t*)malloc(sizeof(bcast_map_t));

		// malloc fail, abort
		if (el == NULL) {
			exit(-1);
		}
		el->sender_id = sender_id;
		el->last_counter = msg_counter;
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
	bool updateBcastMap(bcast_map_t **l, uint16_t sender_id, uint16_t msg_counter) {
		bcast_map_t *el = findById(*l, sender_id);

		// id not present in map, insert a new element in the map
		if (el == NULL) {
			el = createMapEl(sender_id, msg_counter);
			el->next = *l;
			*l = el;
			logMessage("Counter", "Consecutive counter for mote %u: %u", sender_id, el->consecutive_counter);
	
			return FALSE;
		}
		// update the already existing element in the map
		else {
			/* cast to uint16_t is necessary to accept as consecutive message the case when last_counter = 255 (max possible value)
			 and msg_counter = 0 due to overflow */
			// case where a consecutive message is received
			if (el->last_counter == (uint16_t)(msg_counter - 1)) {
				el->last_counter = msg_counter;
				el->consecutive_counter++;
				logMessage("Counter", "Consecutive counter for mote %u: %u", sender_id, el->consecutive_counter);
		
				// check if enough consecuive messages have been received for an alarm trigger 
				if (el->consecutive_counter >= ALARM_TRIGGER_COUNT) {
					// reset counter
					logMessage("Counter", "Counter reset after alarm triggering");
					el->consecutive_counter = 0;
					
					return TRUE;
				}
				else {
					return FALSE;
				}
			}
			// non consecutive message case
			else {
				el->last_counter = msg_counter;
				el->consecutive_counter = 1;	// set immediately to 1 instead of reset and increment
				logMessage("Counter", "Counter reset because non consecutive message is received, new counter for mote %u: %u", sender_id, el->consecutive_counter);
				
				return FALSE;
			}
		}
	}
    
    // ---------------------------------------------------------------------
    
    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            call MilliTimer.startPeriodic(FREQ);
            logMessage("Timer", "Started timer of %d ms", FREQ);
        }
        else {
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {
        // do nothing
    }
    
    event void MilliTimer.fired() {
        if (locked) {
            return;
        }
        else {
            radio_id_msg_t* rcm = (radio_id_msg_t*)call Packet.getPayload(&packet, sizeof(radio_id_msg_t));
            if (rcm == NULL) {
                return;
            }

            rcm->sender_id = TOS_NODE_ID;
            rcm->counter = counter;
            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_id_msg_t)) == SUCCESS) {
                locked = TRUE;
                logMessage("Radio", "Broadcast message sent");
                counter++;
            }
        }
    }

    event message_t* Receive.receive(message_t* bufPtr, 
                    void* payload, uint8_t len) {
        if (len != sizeof(radio_id_msg_t)) {
        	logMessage("Error", "Invalid packet received"); 
            return bufPtr;
        }
        else {
            radio_id_msg_t* rcm = (radio_id_msg_t*) payload;
            
            logMessage("Radio", "Received broadcast id packet: sender %u, counter %u", rcm->sender_id, rcm->counter);
            
            if (updateBcastMap(&map, rcm->sender_id, rcm->counter)) {	        
		        logMessage("Alarm", "mote_id: %u, proximity_mote_id: %u", TOS_NODE_ID, rcm->sender_id);
            }
            
            return bufPtr;
        }
    }

    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
        if (&packet == bufPtr) {
            locked = FALSE;
        }
    }

}
