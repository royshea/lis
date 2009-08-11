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
 * Date last modified: 4/14/09
 */
#include "MultihopLogTap.h"

module MultihopLogTapP
{
    uses interface Boot;

    uses interface SplitControl as RadioControl;
    uses interface SplitControl as SerialControl;
    uses interface StdControl as RoutingControl;

    uses interface Send;
    uses interface AMSend as SerialSend;

    uses interface Receive as Snoop;
    uses interface Receive;
    uses interface RootControl;

    uses interface Pool<message_t> as LogUartPool;
    uses interface Queue<message_t *> as LogUartQueue;

    uses interface Pool<message_t> as CtpSendPool;
    uses interface Queue<message_t *> as CtpSendQueue;

    provides interface LogTap;
}

implementation
{
    void popUartQueue();
    void popSendQueue();

    bool uartbusy = FALSE;
    bool sendbusy = FALSE;
    message_t uartbuf;
    message_t sendbuf;


    event void Boot.booted()
    {
        call RadioControl.start();
        call RoutingControl.start();
    }


    event void RadioControl.startDone(error_t err)
    {
        if (err != SUCCESS)
            call RadioControl.start();
        else
        {
            call SerialControl.start();
        }
    }


    event void SerialControl.startDone(error_t error) {
        if (error != SUCCESS)
            call SerialControl.start();

        /* Set collector roots */
        if (TOS_NODE_ID % 25 == 0)
            call RootControl.setRoot();
    }


    event void RadioControl.stopDone(error_t error) { }


    event void SerialControl.stopDone(error_t error) { }


    task void uartSendTask()
    {
        if (call SerialSend.send(0xffff, &uartbuf, sizeof(LogTapMsg)) != SUCCESS)
        {
            uartbusy = FALSE;
            popUartQueue();
        }
    }


    /* Recieved messages (only occures at root) are passed out over the
     * serial interface. */
    event message_t* Receive.receive(message_t* msg, void *payload, uint8_t len)
    {
        LogTapMsg* in = (LogTapMsg*)payload;
        LogTapMsg* out;

        if (uartbusy == FALSE)
        {
            uartbusy = TRUE;
            out = (LogTapMsg*) call SerialSend.getPayload(&uartbuf, sizeof(LogTapMsg));
            if (len > sizeof(LogTapMsg) || out == NULL)
            {
                uartbusy = FALSE;
                return msg;
            }
            memcpy(out, in, sizeof(LogTapMsg));
            post uartSendTask();
        }
        else
        {
            /* Queue messages if UART is busy. */
            message_t *newmsg = call LogUartPool.get();

            /* Drop the packet if the queue is full. */
            if (newmsg == NULL) return msg;

            out = (LogTapMsg*) call SerialSend.getPayload(newmsg, sizeof(LogTapMsg));
            if (out == NULL)
                return msg;

            memcpy(out, in, sizeof(LogTapMsg));

            /* Big problem.  Ran out of queue space without running out
             * of messages in the pool.  Something is amis. */
            if (call LogUartQueue.enqueue(newmsg) != SUCCESS) {
                call LogUartPool.put(newmsg);
                return msg;
            }
        }
        return msg;
    }


    event void SerialSend.sendDone(message_t *msg, error_t error)
    {
        uartbusy = FALSE;
        popUartQueue();
    }


    void popUartQueue()
    {
        if (call LogUartQueue.empty() == FALSE) {
            /* Keep popping messages off of the UART queue */
            message_t *queuemsg = call LogUartQueue.dequeue();

            /* This shouldn't happen... */
            if (queuemsg == NULL)
                return;

            memcpy(&uartbuf, queuemsg, sizeof(message_t));

            /* This should also not happen... */
            if (call LogUartPool.put(queuemsg) != SUCCESS)
                return;

            post uartSendTask();
        }
    }


    /* TODO: Could add multihop oscilliscope type message
     * synchronization. */
    event message_t* Snoop.receive(message_t* msg, void* payload, uint8_t len)
    {
        return msg;
    }


    event void Send.sendDone(message_t* msg, error_t error)
    {
        sendbusy = FALSE;
        popSendQueue();
    }


    error_t send_log(void *data, uint8_t len) @C() @spontaneous()
    {
        return call LogTap.sendLog(data, len);
    }


    task void logTapSendTask()
    {
        if (call Send.send(&sendbuf, sizeof(LogTapMsg)) != SUCCESS)
        {
            sendbusy = FALSE;
            popSendQueue();
        }
    }


    void popSendQueue()
    {
        if (call CtpSendQueue.empty() == FALSE) {
            /* Keep popping messages off of the UART queue */
            message_t *queuemsg = call CtpSendQueue.dequeue();

            /* This shouldn't happen... */
            if (queuemsg == NULL)
                return;

            memcpy(&sendbuf, queuemsg, sizeof(message_t));

            /* This should also not happen... */
            if (call CtpSendPool.put(queuemsg) != SUCCESS)
                return;

            post logTapSendTask();
        }
    }


    command error_t LogTap.sendLog(void *data, uint8_t len)
    {
        LogTapMsg *logMsg;
        LogTapMsg* out;

        if (!sendbusy)
        {
            sendbusy = TRUE;
            logMsg = (LogTapMsg *)call Send.getPayload(&sendbuf, sizeof(LogTapMsg));

            if (logMsg == NULL)
            {
                sendbusy = FALSE;
                return FAIL;
            }

            memcpy(logMsg, data, len);

            post logTapSendTask();
        }
        else
        {
            /* Queue messages if UART is busy. */
            message_t *newmsg = call CtpSendPool.get();

            /* Drop the packet if the queue is full. */
            if (newmsg == NULL)
                return FAIL;

            out = (LogTapMsg*) call Send.getPayload(newmsg, sizeof(LogTapMsg));
            if (out == NULL)
                return FAIL;

            memcpy(out, data, len);

            /* Big problem.  Ran out of queue space without running out
             * of messages in the pool.  Something is amis. */
            if (call CtpSendQueue.enqueue(newmsg) != SUCCESS) {
                call CtpSendPool.put(newmsg);
                return FAIL;
            }
        }
        return SUCCESS;
    }

}
