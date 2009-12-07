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

configuration LogTapC
{

    uses interface Boot;
    provides interface LogTap;
}

implementation
{
    /* Basic startup */
    components LogTapP;
    Boot = LogTapP;
    LogTap = LogTapP;

    /* Mechanism for sending logs out over the UART */
    components SerialActiveMessageC as LogSerialMessageC;
    components new SerialAMSenderC(AM_LOGTAP) as LogSerialSender;

    LogTapP.SerialControl -> LogSerialMessageC;
    LogTapP.SerialSend -> LogSerialSender.AMSend;
   
    /* Buffer for UART messages. */ 
    components new PoolC(message_t, 2) as LogUartPoolP;
    components new QueueC(message_t*, 2) as LogUartQueueP;

    LogTapP.LogUartPool -> LogUartPoolP;
    LogTapP.LogUartQueue -> LogUartQueueP;

}
