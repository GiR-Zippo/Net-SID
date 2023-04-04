#include "serial.h"

Serial::Serial()
{
#ifdef CE_WINDOWS
    com = new ceSerial("\\\\.\\COM5",600000,8,'N',1); // Windows
#else
    com = new ceSerial("/dev/ttyS0",600000,8,'N',1); // Linux
#endif

    if (com->Open() != 0)
        QMessageBox::critical(NULL,"QTCPServer", "Unable to start the serial: 5.");

    _queue = new SharedQueue<QByteArray>;
    BufferFull = false;
    ResetStates = false;
    _sidBitmask = 0b00000000;

    WriteBufferThread *_writeThread = new WriteBufferThread(this);
    ReadStateThread *_readThread = new ReadStateThread(this, _writeThread);
    _writeThread->start();
    _readThread->start();
}

void Serial::ResetSID()
{
    _queue->Clear();
    MuteAudio(true);

    QByteArray data;
    for (int i =0; i != 150; i++)
    {
        data.append((byte)0x00);
        data.append((byte)0x00);
        data.append((byte)0);
        data.append((byte)0);
        writeData(data);
    }

    data.clear();
    data.append((byte)0xFF);
    data.append(_sidBitmask ^ (byte)0b10000000);
    data.append((byte)0);
    data.append((byte)0);
    writeData(data);

    data[1] = data[1] ^ (byte)0b10000000;
    writeData(data);

    MuteAudio(false);
}

void Serial::toggleBitmask(int position, bool set)
{
    if (set)
        _sidBitmask |= 1UL << position;
    else
        _sidBitmask &= ~(1UL << position);
}

void Serial::MuteAudio(bool do_it)
{
    toggleBitmask(0, do_it);
    QByteArray data;
    data.append((byte)0xFF);
    data.append(_sidBitmask);
    data.append((byte)0);
    data.append((byte)0);
    writeData(data);
}

void Serial::SetSidFilter(byte type)
{
    toggleBitmask(0, type ? true : false);
    QByteArray data;
    data.append((byte)0xFF);
    data.append(_sidBitmask);
    data.append((byte)0);
    data.append((byte)0);
    WriteToQueue(data);
}

void Serial::SetSidType(byte type)
{
    SetSidFilter(type);
    toggleBitmask(1, type == 1 ? true : false);
    ResetSID();
}

void Serial::writeData(QByteArray data)
{
    com->Write(data.data(), data.length());
}

QByteArray Serial::readData()
{
    bool successFlag = false;
    QByteArray bytes = "";

    bytes.append(com->ReadChar(successFlag));
    if (bytes[0] == '\r')
        bytes.clear();
    return bytes;
}

/* ----- Hier werden die Daten vom Serial abgenommen ----- */
ReadStateThread::ReadStateThread(Serial *serial, WriteBufferThread *wb) :
    _serial(serial), _wb(wb)
{
}

void ReadStateThread::run()
{
    while (!QThread::currentThread()->isInterruptionRequested())
    {
        if (_serial->ResetStates)
        {
            _wb->Wait = false;
            _serial->BufferFull.store(false);
            _serial->ResetStates = false;
        }

        //Ask if buffer is full
        QByteArray serdat = _serial->readData();
        if (serdat.length() > 0)
        {
            bool wait = false;
            if (serdat[0] == 'E')
            {
                wait = true;
                _wb->Wait = wait;
                _serial->BufferFull.store(wait);
            }

            while (wait)
            {
                //Ask if buffer is empty
                QByteArray serdat = _serial->readData();
                if (serdat[0] == 'S')
                {
                    wait = false;
                    _wb->Wait = wait;
                    _serial->BufferFull.store(wait);
                }
                QThread::usleep(500);
            }
        }
        QThread::usleep(500);
    }
}

/* ----- Hier wird sie Queue abgearbeitet ----- */
WriteBufferThread::WriteBufferThread(Serial *serial) :
    _serial(serial)
{
    Wait.store(false);
}

void WriteBufferThread::run()
{
    while (!QThread::currentThread()->isInterruptionRequested())
    {
        while(_serial->GetQueue()->size() >0  && !Wait)
        {
            if ( QThread::currentThread()->isInterruptionRequested() )
                return;
            _serial->writeData(_serial->GetQueue()->front());
            _serial->GetQueue()->pop_front();
        }
        QThread::usleep(500);
    }
}
