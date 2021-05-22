#include "Timer.h"
#include "KeepYourDistance.h"
//#include "printf.h"
//#include "BcastMap.h"

#include <stdio.h>
#include <stdarg.h>

#define FREQ 500
#define ALARM_TRIGGER_COUNT 10

module KeepYourDistanceC @safe() {
  uses {
    interface Leds;
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
    uint8_t counter = 0;
    
    bcast_map_t *map = NULL;
    
    //-----------------------------------------------------------------------

	bcast_map_t* createMapEl(uint16_t sender_id, uint8_t msg_counter) {
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
	bool updateBcastMap(bcast_map_t **l, uint16_t sender_id, uint8_t msg_counter) {
		bcast_map_t *el = findById(*l, sender_id);

		// id not present in map, insert a new element in the map
		if (el == NULL) {
			el = createMapEl(sender_id, msg_counter);
			el->next = *l;
			*l = el;
	
			return FALSE;
		}
		// update the already existing element
		else {
			// a consecutive message is received
			if (el->last_counter == msg_counter - 1) {
				el->last_counter = msg_counter;
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
				el->last_counter = msg_counter;
				el->consecutive_counter = 1;
				return FALSE;
			}
		}
	}
    
    //-----------------------------------------------------------------------

    void logMessage(char *debug_ch, char *fmt, ...) {
        char formatted_string[255];

        va_list argptr;
        va_start(argptr,fmt);
        vsprintf(formatted_string, fmt, argptr);
        va_end(argptr);

        printf("[%s] (ID: %u) %s\n", debug_ch, TOS_NODE_ID, formatted_string);
        //printfflush();
    }
    
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
        if (len != sizeof(radio_id_msg_t) && len != sizeof(radio_alarm_msg_t)) {
        	logMessage("Error", "Invalid packet received"); 
            return bufPtr;
        }
        else if (len == sizeof(radio_alarm_msg_t)) {
            // TODO: create socket with node red
            logMessage("Error", "Alarm should not be received by motes!");
            return bufPtr;
        }
        else {
            radio_id_msg_t* rcm = (radio_id_msg_t*) payload;
            
            logMessage("Radio", "Received packet: sender %u, counter %u", rcm->sender_id, rcm->counter);
            
            if (updateBcastMap(&map, rcm->sender_id, rcm->counter)) {
            	// send alarm message
            	/*radio_alarm_msg_t* alarm = (radio_alarm_msg_t*)call Packet.getPayload(&packet, sizeof(radio_alarm_msg_t));
		        if (alarm == NULL) {
		            return;
		        }

		        alarm->mote_id = TOS_NODE_ID;
		        alarm->proximity_mote_id = rcm->sender_id;
		        if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_alarm_msg_t)) == SUCCESS) {
		            locked = TRUE;
		            logMessage("Radio", "Alarm message sent");
		        }*/
		        
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
