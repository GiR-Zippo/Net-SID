#ifndef SERVER_H
#define SERVER_H

#include <QTimer>
#include <QThread>

#include <QStandardPaths>
#include <QTcpServer>
#include <QTcpSocket>
#include <QMessageBox>
#include "TQueue.h"
#include "ceSerial.h"
using namespace ce;

class Serial;
class WriteBufferThread : public QThread
{
public:
    explicit WriteBufferThread(Serial *serial);
    std::atomic<bool> Wait;
    void run();
private:
    Serial *_serial;
};

class ReadStateThread : public QThread
{
public:
    explicit ReadStateThread(Serial *serial, WriteBufferThread *wb);

    void run();

private:
    Serial *_serial;
    WriteBufferThread *_wb;
};

class Serial
{
    friend class ReadStateThread;
    friend class WriteBufferThread;
    public:
        Serial();

        void ResetSID();
        void MuteAudio(bool do_it);
        void SetSidFilter(byte type);
        void SetSidType(byte type);

        void WriteToQueue(QByteArray data)
        {
            _queue->push_back(data);
        }

        std::atomic<bool> ResetStates;
        std::atomic<bool> BufferFull;

        SharedQueue<QByteArray> *GetQueue() {return _queue;}

    private:
        void writeData(QByteArray data);
        QByteArray readData();
        void toggleBitmask(int position, bool set);
    private:
        ceSerial *com;
        SharedQueue<QByteArray> *_queue;
        WriteBufferThread *_writeThread;
        ReadStateThread *_readThread;
        byte _sidBitmask;
};



#endif // SERVER_H
