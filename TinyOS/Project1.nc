#include "Timer.h"
#include "Project1.h"
#include "printf.h"

module Project1 @safe() {
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

    bool locked;
    uint16_t counter = 0;
    bool led0_ON = 0;
    bool led1_ON = 0;
    bool led2_ON = 0;
    double freq;
    
    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        
        if (err == SUCCESS) {
            switch (TOS_NODE_ID) {
            case 1: 
                freq = 1000.0;
                break;
            case 2: 
                freq = 1000.0/3;
                break;
            case 3: 
                freq = 1000.0/5;
                break;
            default:
                freq = 100000.0;
                break;
            }
            //printf("Start timer of %f ms\n", freq);
            //printfflush();
            call MilliTimer.startPeriodic(freq);
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
            radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(radio_count_msg_t));
            if (rcm == NULL) {
                return;
            }

            rcm->counter = counter;
            rcm->sender_id = TOS_NODE_ID;
            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
                locked = TRUE;
            }
        }
    }

    event message_t* Receive.receive(message_t* bufPtr, 
                    void* payload, uint8_t len) {
        if (len != sizeof(radio_count_msg_t)) { 
            return bufPtr;
        }
        else {
            radio_count_msg_t* rcm = (radio_count_msg_t*) payload;
            counter++;
            
            printf("Received packet from %u, counter: %u\n", rcm->sender_id, rcm->counter);
            printfflush();

            if (rcm->sender_id == 1) {
                call Leds.led0Toggle();
                led0_ON = !led0_ON;
            }
            else if (rcm->sender_id == 2) {
                call Leds.led1Toggle();
                led1_ON = !led1_ON;
            }
            else if (rcm->sender_id == 3) {
                call Leds.led2Toggle();
                led2_ON = !led2_ON;
            }

            if (rcm->counter % 10 == 0) {
                call Leds.led0Off();
                call Leds.led1Off();
                call Leds.led2Off();
                
                led0_ON = 0;
                led1_ON = 0;
                led2_ON = 0;
                
                printf("Reset\n");
            	printfflush();
            }
            
            printf("LEDS: %u%u%u, counter: %u\n", led2_ON, led1_ON, led0_ON, counter);
            printfflush();
            
            return bufPtr;
        }
    }

    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
        if (&packet == bufPtr) {
            locked = FALSE;
        }
    }

}




