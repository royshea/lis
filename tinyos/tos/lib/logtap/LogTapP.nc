/*
 * "Copyright (c) 2009 The Regents of the University  of California.
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written
 * agreement is hereby granted, provided that the above copyright
 * notice, the following two paragraphs and the author appear in all
 * copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
 * IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
 * CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
 * UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Author: Roy Shea (royshea@gmail.com)
 * Date last modified: 2/25/09
 */
#include "LogTap.h"

module LogTapP
{
    uses interface Boot;
    uses interface Packet;
    uses interface AMSend;
    uses interface SplitControl as AMControl;
    uses interface Queue<message_t> as Queue;
    provides interface LogTap;
}

implementation
{
    enum {
        S_STOPPED,
        S_STARTED,
        S_FLUSHING,
      };

    message_t send_msg;
    uint8_t state = S_STOPPED;

    event void Boot.booted()
    {
        call AMControl.start();
    }


    event void AMControl.startDone(error_t err)
    {
        if (err == SUCCESS)
            atomic state = S_STARTED;
        else
            call AMControl.start();
    }


    event void AMControl.stopDone(error_t err)
    {
        atomic state = S_STOPPED;
    }


    task void retrySend() {
        if(call AMSend.send(AM_BROADCAST_ADDR, &send_msg, sizeof(LogTapMsg)) != SUCCESS)
            post retrySend();
    }


    void sendNext()
    {
        memset(&send_msg, 0, sizeof(message_t));
        send_msg = call Queue.dequeue();
        if(call AMSend.send(AM_BROADCAST_ADDR, &send_msg, sizeof(LogTapMsg)) != SUCCESS)
            post retrySend();
    }


    event void AMSend.sendDone(message_t* msg, error_t error) {
        if(error == SUCCESS) {
            if(call Queue.size() > 0)
                sendNext();
            else state = S_STARTED;
        }
        else post retrySend();
    }


    error_t send_log(void *data, uint8_t len) @C() @spontaneous()
    {
        return call LogTap.sendLog(data, len);
    }


    command error_t LogTap.sendLog(void *data, uint8_t len)
    {
        LogTapMsg *logMsg;
        message_t tmp_msg;

        if((state == S_STARTED) && (call Queue.size() >= 5)) {
            state = S_FLUSHING;
            sendNext();
        }

        logMsg = (LogTapMsg *)call AMSend.getPayload(&tmp_msg, sizeof(LogTapMsg));
        if (logMsg == NULL)
        {
            return FAIL;
        }

        memcpy(logMsg, data, len);
        atomic {
            if (call Queue.enqueue(tmp_msg) != SUCCESS)
            {
                return FAIL;
            }
            return SUCCESS;
        }
    }


}
