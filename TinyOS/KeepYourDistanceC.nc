#include "Timer.h"
#include "KeepYourDistance.h"
#include "printf.h"

#include <stdio.h>
#include <stdarg.h>

#define FREQ 500

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
    uint16_t counter = 0;

    void logMessage(char *debug_ch, char *fmt, ...) {
        char formatted_string[255];

        va_list argptr;
        va_start(argptr,fmt);
        vsprintf(formatted_string, fmt, argptr);
        va_end(argptr);

        printf("[%s] (ID: %u) %s\n", debug_ch, TOS_NODE_ID, formatted_string);
        printfflush();
    }
    
    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        
        if (err == SUCCESS) {
            call MilliTimer.startPeriodic(FREQ);
            logMessage("Timer", "Started timer of %f ms", FREQ);
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
            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_id_msg_t)) == SUCCESS) {
                locked = TRUE;
                logMessage("Radio", "Broadcast message sent");
            }
        }
    }

    event message_t* Receive.receive(message_t* bufPtr, 
                    void* payload, uint8_t len) {
        if (len != sizeof(radio_id_msg_t) && len != sizeof(radio_alarm_msg_t)) { 
            return bufPtr;
        }
        else if (len == sizeof(radio_alarm_msg_t)) {
            // TODO: create socket with node red
            return bufPtr;
        }
        else {
            radio_id_msg_t* rcm = (radio_id_msg_t*) payload;
            // TODO: counter can be useful to know if 10 consecutive messages are received
            counter++;
            
            logMessage("Radio", "Received packet from %u", rcm->sender_id);

            // TODO
            
            return bufPtr;
        }
    }

    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
        if (&packet == bufPtr) {
            locked = FALSE;
        }
    }

}
