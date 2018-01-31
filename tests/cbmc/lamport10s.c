#include <pthread.h>

void fence() {asm("sync");}

int X, Y = 0, CS;

void * thr0(void *p)
{
    for (;;)
    {
	do
	{
	    X = 1;
	    fence();	
	} while (Y != 0);
	Y = 1;
	fence();
	if (X != 1)
	{
	    if (Y != 1) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 1;
	assert(CS == 1);
	
	Y = 0;
    }
}
void * thr1(void *p)
{
    for (;;)
    {
	do
	{
	    X = 2;
	    fence();	
	} while (Y != 0);
	Y = 2;
	fence();
	if (X != 2)
	{
	    if (Y != 2) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 2;
	assert(CS == 2);
	
	Y = 0;
    }
}

void * thr2(void *p)
{
    for (;;)
    {
	do
	{
	    X = 3;
	    fence();	
	} while (Y != 0);
	Y = 3;
	fence();
	if (X != 3)
	{
	    if (Y != 3) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 3;
	assert(CS == 3);
	
	Y = 0;
    }
}

void * thr3(void *p)
{
    for (;;)
    {
	do
	{
	    X = 4;
	    fence();	
	} while (Y != 0);
	Y = 4;
	fence();
	if (X != 4)
	{
	    if (Y != 4) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 4;
	assert(CS == 4);
	
	Y = 0;
    }
}

void * thr4(void *p)
{
    for (;;)
    {
	do
	{
	    X = 5;
	    fence();	
	} while (Y != 0);
	Y = 5;
	fence();
	if (X != 5)
	{
	    if (Y != 5) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 5;
	assert(CS == 5);
	
	Y = 0;
    }
}

void * thr5(void *p)
{
    for (;;)
    {
	do
	{
	    X = 6;
	    fence();
	} while (Y != 0);
	Y = 6;
	fence();
	if (X != 6)
	{
	    if (Y != 6) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 6;
	assert(CS == 6);
	
	Y = 0;
    }
}

void * thr6(void *p)
{
    for (;;)
    {
	do
	{
	    X = 7;
	    fence();
	} while (Y != 0);
	Y = 7;
	fence();
	if (X != 7)
	{
	    if (Y != 7) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 7;
	assert(CS == 7);
	
	Y = 0;
    }
}

void * thr7(void *p)
{
    for (;;)
    {
	do
	{
	    X = 8;
	    fence();
	} while (Y != 0);
	Y = 8;
	fence();
	if (X != 8)
	{
	    if (Y != 8) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 8;
	assert(CS == 8);
	
	Y = 0;
    }
}

void * thr8(void *p)
{
    for (;;)
    {
	do
	{
	    X = 9;
	    fence();
	} while (Y != 0);
	Y = 9;
	fence();
	if (X != 9)
	{
	    if (Y != 9) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 9;
	assert(CS == 9);
	
	Y = 0;
    }
}

void * thr9(void *p)
{
    for (;;)
    {
	do
	{
	    X = 10;
	    fence();
	} while (Y != 0);
	Y = 10;
	fence();
	if (X != 10)
	{
	    if (Y != 10) continue;
	    for (;;);
	}

	/* Critical Section */
	CS = 10;
	assert(CS == 10);
	
	Y = 0;
    }
}

int main()
{
    pthread_create(NULL, NULL, thr0, NULL);
    pthread_create(NULL, NULL, thr1, NULL);
    pthread_create(NULL, NULL, thr2, NULL);
    pthread_create(NULL, NULL, thr3, NULL);
    pthread_create(NULL, NULL, thr4, NULL);
    pthread_create(NULL, NULL, thr5, NULL);
    pthread_create(NULL, NULL, thr6, NULL);
    pthread_create(NULL, NULL, thr7, NULL);
    pthread_create(NULL, NULL, thr8, NULL);
    pthread_create(NULL, NULL, thr9, NULL);
    return 0;
}