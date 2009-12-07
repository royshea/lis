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
 * Date: Dec. 2009
 */
#include "LogTap.h"

module LogTapP
{
    uses interface Boot;

    uses interface SplitControl as SerialControl;
    
    uses interface AMSend as SerialSend;

    uses interface Pool<message_t> as LogUartPool;
    uses interface Queue<message_t *> as LogUartQueue;

    provides interface LogTap;
}

implementation
{
    void popUartQueue();
    bool uartbusy = FALSE;
    message_t uartbuf;

    event void Boot.booted()
    {
        call SerialControl.start();
    }


    event void SerialControl.startDone(error_t err)
    {
        if (err != SUCCESS)
            call SerialControl.start();
    }


    event void SerialControl.stopDone(error_t err) { }


    task void uartSendTask()
    {
        if (call SerialSend.send(0xffff, &uartbuf, sizeof(LogTapMsg)) != SUCCESS)
        {
            uartbusy = FALSE;
            popUartQueue();
        }
    }


    error_t send_log(void *data, uint8_t len) @C() @spontaneous()
    {
        return call LogTap.sendLog(data, len);
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


    command error_t LogTap.sendLog(void *data, uint8_t len)
    {
        LogTapMsg* in = (LogTapMsg*)data;
        LogTapMsg* out;

        if (uartbusy == FALSE)
        {
            uartbusy = TRUE;
            out = (LogTapMsg*) call SerialSend.getPayload(&uartbuf, sizeof(LogTapMsg));
            if (len > sizeof(LogTapMsg) || out == NULL)
            {
                uartbusy = FALSE;
                return FAIL;
            }
            memcpy(out, in, sizeof(LogTapMsg));
            post uartSendTask();
        }
        else
        {
            /* Queue messages if UART is busy. */
            message_t *newmsg = call LogUartPool.get();

            /* Drop the packet if the queue is full. */
            if (newmsg == NULL) return FAIL;

            out = (LogTapMsg*) call SerialSend.getPayload(newmsg, sizeof(LogTapMsg));
            if (out == NULL) return FAIL;

            memcpy(out, in, sizeof(LogTapMsg));

            /* Big problem.  Ran out of queue space without running out
             * of messages in the pool.  Something is amis. */
            if (call LogUartQueue.enqueue(newmsg) != SUCCESS) {
                call LogUartPool.put(newmsg);
                return FAIL;
            }
        }
        return SUCCESS;
    }
}
