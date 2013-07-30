#include "common.h"

class Intel8259PIC : public ISA8BitComponent
{
public:
	void simulateCycle()
	{
	}
	void setAddress(UInt32 address)
    {
        _address = address & 0xf;
        _active = (address & 0x400003f0) == 0x40000020;
    }
	void read()
	{
	}
	void write(UInt8 data)
	{
		switch(_address)
		{
		case 0:
			if(data & 0x10)
			{
				_icw1 = data & 0x0F;
				_state = stateICW2;
			}
			break;
		case 1:
			if(_state == stateICW2)
			{
				_offset = data;
				_state = stateICW3;
			}
			if(_state == stateICW3)
			{
				_offset = data;
				if(_icw1 & 1) _state = stateICW4;
				else _state = stateReady;
			}
			if(_state == stateICW4)
			{
				_icw4 = data;
				_state = stateReady;
			}
			break;
		}
	}

	void handleInterrupt()
	{
		if(_state == stateReady)
		{
			_bus->_interruptnum += _offset;
			_bus->_interruptrdy = true;
			_bus->_interrupt = false;
		}
		else
		{
			_bus->_interrupt = false;
		}
	}
private:
	enum State
	{
		stateReady,
		stateICW2,
		stateICW3,
		stateICW4,
	} _state;

	UInt32 _address;
	UInt8 _offset;
	UInt8 _irr;
	UInt8 _isr;
	UInt8 _imr;

	UInt8 _icw1;
	UInt8 _icw4;
};