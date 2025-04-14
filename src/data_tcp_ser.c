#include <stdio.h>
#include <string.h>
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "xil_printf.h"
#include "hw_misc.h"
#include "data_tcp_ser.h"

#define DATA_TCP_SER_PORT  1001

u32 tcp_rx_bytes_count;
u32 tcp_tx_bytes_count;
u8  tcp_path=0x01;
static struct tcp_pcb *connected_dts_pcb=NULL;

static err_t dts_recv_callback(void *arg, struct tcp_pcb *tpcb, struct pbuf *p, err_t err)
{
	u16 ava_len;
	u16 spare_len;
	int ret;

	// do not read the packet if we are not in ESTABLISHED state
	if (!p) {
		tcp_close(tpcb);
		tcp_recv(tpcb, NULL);
		connected_dts_pcb=NULL;
		return ERR_OK;
	}

	tcp_recved(tpcb, p->tot_len);     // indicate that the packet has been received
	tcp_rx_bytes_count+=p->tot_len;   // inc tcp_rx_bytes_count

	if(p->tot_len>(BLOCK_SIZE*4))
		xil_printf("Warning: large tcp tot_len=%d\r\n",p->tot_len);

	// tcp path=0x03: Remote->PS->Remote
	// tcp_path=0x11: Remote->PS->PL
	// tcp_path=0x13: Remote->PS->PL->PS->Remote
	// These pathes need merge rx_data to 4096-byte block
	if((tcp_path==0x03)||(tcp_path==0x11)||(tcp_path==0x13))
	{
		//@producer: fill a packet to dma_cbf (supposed the tot_len always less than DMA_CBF_LEN-BLOCK_SIZE)
		spare_len=DMA_CBF_LEN-dma_cbf.ptr_write;
		if(spare_len>=p->tot_len)
			pbuf_copy_partial(p, &(dma_cbf.pbuf[dma_cbf.ptr_write]), p->tot_len,0);
		else
		{
			pbuf_copy_partial(p, &(dma_cbf.pbuf[dma_cbf.ptr_write]), spare_len, 0);
			pbuf_copy_partial(p, &(dma_cbf.pbuf[0]), p->tot_len-spare_len, spare_len);
		}
		// Update ptr write
		dma_cbf.ptr_write=(dma_cbf.ptr_write+p->tot_len)%DMA_CBF_LEN;

		//@consumer : if spare_len>BLOCK_SIZE, consume a block
		ava_len=(DMA_CBF_LEN+dma_cbf.ptr_write-dma_cbf.ptr_read)%DMA_CBF_LEN;
		if(ava_len>=BLOCK_SIZE)
		{
			//DMA send a block to PL (PS->PL)
			if((tcp_path==0x11)||(tcp_path==0x13))
			{
				ret=RUN_DMA_OUT((&(dma_cbf.pbuf[dma_cbf.ptr_read])));  //Make a DMA: PS->PL
				if(ret)
					xil_printf("Error: RUN_DMA_OUT Failed in DATA TCP!\r\n");
			}

			//DMA read a block from PL (PL->PS)
			if(tcp_path==0x13)
			{
				write_pl_reg(0x0018,0x00000003); //force usr_pl to copy Tx_RAM to RxRAM
				ret=RUN_DMA_IN((&(dma_cbf.pbuf[dma_cbf.ptr_read])));  //Make a DMA: PL->PS
				if(ret)
					xil_printf("Error: RUN_DMA_IN Failed IN DATA TCP!\r\n");
			}

			//TCP send a block to remote (PS->Remote)
			if((tcp_path==0x03)||(tcp_path==0x13))
			{
				if (tcp_sndbuf(tpcb)>p->tot_len) //make sure TCP_SND_BUF > tot_len
				{
					tcp_write(tpcb, &(dma_cbf.pbuf[dma_cbf.ptr_read]), BLOCK_SIZE, 1);
					tcp_tx_bytes_count+=BLOCK_SIZE;
				}
				else
					xil_printf("Error: tcp_sndbuf space not enough, drop a block..!\r\n");
			}

			//Update ptr read
			dma_cbf.ptr_read=(BLOCK_SIZE+dma_cbf.ptr_read)%DMA_CBF_LEN; //Update ptr_read
		}
	}
	else  // path: Remote->PS
	{
		// do nothing, just ignore the received pbuf
	}

	pbuf_free(p);  //free the received pbuf
	return ERR_OK;
}


// this will be called from main loop
// when data path = 02 or 12, will tx data to PC from here
void dts_tx()
{
	static u8 run_flag=0;
	static u16 id=0x0000;
	int ret;

	if((connected_dts_pcb==NULL)||(connected_dts_pcb->state!=ESTABLISHED))
	{
		if(run_flag)
			xil_printf("tcp close, tcp_rx_bytes_count=%u, tcp_tx_bytes_count=%u\r\n",tcp_rx_bytes_count,tcp_tx_bytes_count);
		run_flag=0;
		id=0x0000;
		return;
	}
	run_flag=1;

	// 02: PS -> Remote
	if(tcp_path==0x02)
	{
		if (tcp_sndbuf(connected_dts_pcb) > BLOCK_SIZE)
		{
			dma_cbf.pbuf[2]=(id>>8)&0xFF;
			dma_cbf.pbuf[3]=id&0xFF;
			id++;
			tcp_write(connected_dts_pcb, dma_cbf.pbuf, BLOCK_SIZE, 1);
			tcp_tx_bytes_count+=BLOCK_SIZE;
		}
	}

	// 12: PL->PS->rRemote
	if(tcp_path==0x12)
	{
		if (tcp_sndbuf(connected_dts_pcb) > BLOCK_SIZE)
		{
			ret=RUN_DMA_IN(dma_cbf.pbuf);  //Make a DMA: PL->PS
			if(ret<0)
			{
				xil_printf("RUN_DMA_IN Failed!\r\n");
				return;
			}
			tcp_write(connected_dts_pcb, dma_cbf.pbuf, BLOCK_SIZE, 1);
			tcp_tx_bytes_count+=BLOCK_SIZE;
		}
	}
}

static err_t dts_accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
	static int connection = 0;
	u32 remote;
	/* set the receive callback for this connection */
	tcp_recv(newpcb, dts_recv_callback);

	/* just use an integer number indicating the connection id as the
	   callback argument */
	tcp_arg(newpcb, (void*)(UINTPTR)connection);
	remote=newpcb->remote_ip.addr;

	xil_printf("DATA TCP server accepted %d-th connection from remote ip=%d.%d.%d.%d port=%d\r\n",
			connection,
			remote&0xff, (remote>>8)&0xff, (remote>>16)&0xff, (remote>>24)&0xff,
			newpcb->remote_port
			);
	tcp_rx_bytes_count=0;
	tcp_tx_bytes_count=0;
	init_dma_cbf(&dma_cbf);

	/* increment for subsequent accepted connections */
	connection++;
	connected_dts_pcb = newpcb;
	return ERR_OK;
}



int start_data_tcp_ser()
{
	struct tcp_pcb *pcb;
	err_t err;
	unsigned port = DATA_TCP_SER_PORT;

	/* create new TCP PCB structure */
	pcb = tcp_new();
	if (!pcb) {
		xil_printf("Error creating PCB. Out of Memory\r\n");
		return -1;
	}

	/* bind to specified @port */
	err = tcp_bind(pcb, IP_ADDR_ANY, port);
	if (err != ERR_OK) {
		xil_printf("Unable to bind to port %d: err = %d\r\n", port, err);
		return -2;
	}

	/* we do not need any arguments to callback functions */
	tcp_arg(pcb, NULL);

	/* listen for connections */
	pcb = tcp_listen(pcb);
	if (!pcb) {
		xil_printf("Out of memory while tcp_listen\r\n");
		return -3;
	}

	tcp_accept(pcb, dts_accept_callback); // specify callback to use for incoming connections
	xil_printf("DATA TCP server started @ port %d\r\n", port);

	return 0;
}
