#define NEW_PRINTF_SEMANTICS
#include "KeepYourDistance.h"
//#include "printf.h"

configuration KeepYourDistanceAppC { }

implementation {
  components MainC, KeepYourDistanceC as App, LedsC;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new TimerMilliC();
  components ActiveMessageC;
  components SerialPrintfC;
  components SerialStartC;

  App.Boot -> MainC.Boot;
  
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TimerMilliC;
  App.Packet -> AMSenderC;
}
