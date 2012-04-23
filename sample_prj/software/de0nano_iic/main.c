// vim: set expandtab ts=4 sts=0 sw=4:

#include "system.h"
#include "io.h"
#include "sys/alt_stdio.h"

// return 0 : success
//        1 : fail
int iic_write(
    unsigned char addr, // 7bit-addr
    int num,
    unsigned char *data )
{
    int i, r, err;

    err = 0;

    IOWR( IIC_0_BASE, 0, 0x100 ); // I2C Start
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("S%x\n", r );

    addr = (addr << 1) | 0;

    IOWR( IIC_0_BASE, 0, addr ); // I2C WRITE
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("C%x\n", r );
    if( r & 0x400 ) { // NACK
        err = 1;
        goto end;
    }

    for( i = 0; i < num; i++ ) {
        IOWR( IIC_0_BASE, 0, data[i] ); // I2C WRITE
        r = IORD( IIC_0_BASE, 0 );
        while( (r & 0x100) ) {
            r = IORD( IIC_0_BASE, 0 );
        }
//      alt_printf("W%x\n", r );
        if( r & 0x400 ) { // NACK
            err = 1;
            goto end;
        }
    }

end:
    IOWR( IIC_0_BASE, 0, 0x200 ); // I2C STOP
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("P%x\n", r );

    return err;
}

// return 0 : success
//        1 : fail
int iic_read(
    unsigned char addr, // 7bit-addr
    int num,
    unsigned char *data )
{
    int i, r, err;

    err = 0;

    IOWR( IIC_0_BASE, 0, 0x100 ); // I2C Start
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("S%x\n", r );

    addr = (addr << 1) | 1;

    IOWR( IIC_0_BASE, 0, addr ); // I2C WRITE
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("C%x\n", r );
    if( r & 0x400 ) { // NACK
        err = 1;
        goto end;
    }

    for( i = 0; i < num-1; i++ ) {
        IOWR( IIC_0_BASE, 0, 0x300 ); // I2C READ with ACK
        r = IORD( IIC_0_BASE, 0 );
        while( (r & 0x100) ) {
            r = IORD( IIC_0_BASE, 0 );
        }
//      alt_printf("R%x\n", r );
        data[i] = r;
    }

    IOWR( IIC_0_BASE, 0, 0x301 ); // I2C READ with NACK
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("R%x\n", r );
    data[i] = r;

end:
    IOWR( IIC_0_BASE, 0, 0x200 ); // I2C STOP
    r = IORD( IIC_0_BASE, 0 );
    while( (r & 0x100) ) {
        r = IORD( IIC_0_BASE, 0 );
    }
//  alt_printf("P%x\n", r );

    return err;
}


int main( void )
{ 
    unsigned char buf[4];

    alt_putstr("Boot\n");

    // I2C Clock Setting
    IOWR( IIC_0_BASE, 1,  42 ); // 100kHz (50,000kHz / 100kHz / 12 = 41.6...)
//  IOWR( IIC_0_BASE, 1,  11 ); // 400kHz (50,000kHz / 400kHz / 12 = 10.4...)

    buf[0] = 0;
    iic_write( 0x1D, 1, buf );
    iic_read( 0x1D, 1, buf );
    alt_printf( "DEVID %x\n", buf[0] );

    /* Event loop never exits. */
    while( 1 ) {
        ;
    }

    return 0;
}
