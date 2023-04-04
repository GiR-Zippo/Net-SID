#include "netsid.h"
#include "./ui_netsid.h"
#include "servercommands.h"
#include "Enums.h"
#include <qthread.h>

#include <iostream>
#include <future>
#include <thread>
#include <chrono>

NetSID::NetSID(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::NetSID)
{
    ui->setupUi(this);
    m_server = new QTcpServer();

    if(m_server->listen(QHostAddress::Any, 6581))
    {
        connect(this, &NetSID::newMessage, this, &NetSID::displayMessage);
        connect(this, &NetSID::bufProgress, this, &NetSID::displayProgress);
        connect(this->ui->panicButton, SIGNAL( clicked()),this,SLOT( panicClicked()));

        connect(m_server, &QTcpServer::newConnection, this, &NetSID::newConnection);
        ui->statusBar->showMessage("Server is listening...");
        _serial = new Serial();
    }
    else
    {
        QMessageBox::critical(this,"QTCPServer",QString("Unable to start the server: %1.").arg(m_server->errorString()));
        exit(EXIT_FAILURE);
    }
}

NetSID::~NetSID()
{
    foreach (QTcpSocket* socket, connection_set)
    {
        socket->close();
        socket->deleteLater();
    }

    m_server->close();
    m_server->deleteLater();

    delete ui;
}

void NetSID::panicClicked()
{
    _serial->SetSidType(0);
    /*if (ui->panicButton->text() == "8580")
    {
        ui->panicButton->setText("6581");
        _serial->SetSidType(0);
    }
    else
    {
        ui->panicButton->setText("8580");
        _serial->SetSidType(1);
    }*/
}

void NetSID::newConnection()
{
    while (m_server->hasPendingConnections())
        appendToSocketList(m_server->nextPendingConnection());
}

void NetSID::appendToSocketList(QTcpSocket* socket)
{
    connection_set.insert(socket);
    connect(socket, &QTcpSocket::readyRead, this, &NetSID::readSocket);
    connect(socket, &QTcpSocket::disconnected, this, &NetSID::discardSocket);
    connect(socket, &QAbstractSocket::errorOccurred, this, &NetSID::displayError);
    //ui->comboBox_receiver->addItem(QString::number(socket->socketDescriptor()));
    displayMessage(QString("INFO :: Client with sockd:%1 has just entered the room").arg(socket->socketDescriptor()));
}

void NetSID::readSocket()
{
    QTcpSocket* socket = reinterpret_cast<QTcpSocket*>(sender());
    QByteArray data = socket->read(4);

    quint8 command = data[0];
    quint8 sidnum = data[1];
    data.remove(0,2);
    QDataStream ds(data);
    ds.setByteOrder(QDataStream::BigEndian);
    short size;
    ds >> size;
    QByteArray InPack;
    if (socket->bytesAvailable() > 0)
        InPack = socket->read(size);

    QString message;
    //message = QString("FLUSH %1").arg(size);
    //emit newMessage(message);
    switch (command)
    {
        case FLUSH:
            message = QString("FLUSH ");
            emit newMessage(message);
            _serial->MuteAudio(true);
            _serial->GetQueue()->Clear();
            socket->write(ServerCommands::CreateOk());
        break;
        case TRY_SET_SID_COUNT:
            message = QString("TRY_SET_SID_COUNT ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateOk());
        break;
        case MUTE:
            message = QString("MUTE ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateOk());
        break;
        case TRY_RESET:
            message = QString("TRY_RESET ");
            emit newMessage(message);
            _serial->ResetStates.store(true);
            _serial->ResetSID();
            emit bufProgress(-1);
            socket->write(ServerCommands::CreateOk());
        break;
        case TRY_DELAY:
            message = QString("TRY_DELAY ");
            emit newMessage(message);
        break;

        //TODO
        case TRY_WRITE:
        {
            if (_serial->BufferFull)
            {
                socket->write(ServerCommands::CreateBusy());
            }
            else
            {
                _serial->WriteToQueue(InPack);
                if (_serial->GetQueue()->size()-20 > 20)
                    std::this_thread::sleep_for(std::chrono::milliseconds(_serial->GetQueue()->size()/2));
                socket->write(ServerCommands::CreateOk());
            }
            emit bufProgress(_serial->GetQueue()->size());
        }
        break;

        case GET_VERSION:
            message = QString("GET_VERSION ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateVersion(2));
        break;
        case TRY_SET_SAMPLING:
            message = QString("TRY_SET_SAMPLING ");
            emit newMessage(message);
            message = InPack;
            emit newMessage(message);
            socket->write(ServerCommands::CreateOk());
        break;
        case TRY_SET_CLOCKING:
            message = QString("TRY_SET_CLOCKING ");
            emit newMessage(message);
            message = InPack;
            emit newMessage(message);
            socket->write(ServerCommands::CreateOk());
        break;
        case GET_CONFIG_COUNT:
            message = QString("GET_CONFIG_COUNT ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateConfigCount(2));
        break;
        case GET_CONFIG_INFO:
            message = QString("GET_CONFIG_INFO ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateConfigInfo(sidnum));
        break;
        case SET_SID_POSITION:
            message = QString("SET_SID_POSITION ");
            emit newMessage(message);
            socket->write(ServerCommands::CreateOk());
        break;
        case TRY_SET_SID_MODEL:
            message = QString("TRY_SET_SID_MODEL ");
            emit newMessage(message);
            _serial->SetSidType(InPack[0]);
            socket->write(ServerCommands::CreateOk());
        break;
    };
}

void NetSID::discardSocket()
{
    QTcpSocket* socket = reinterpret_cast<QTcpSocket*>(sender());
    QSet<QTcpSocket*>::iterator it = connection_set.find(socket);
    if (it != connection_set.end()){
        displayMessage(QString("INFO :: A client has just left the room").arg(socket->socketDescriptor()));
        connection_set.remove(*it);
    }
    socket->deleteLater();
}

void NetSID::displayError(QAbstractSocket::SocketError socketError)
{
    switch (socketError) {
    case QAbstractSocket::RemoteHostClosedError:
        break;
    case QAbstractSocket::HostNotFoundError:
        QMessageBox::information(this, "QTCPServer", "The host was not found. Please check the host name and port settings.");
        break;
    case QAbstractSocket::ConnectionRefusedError:
        QMessageBox::information(this, "QTCPServer", "The connection was refused by the peer. Make sure QTCPServer is running, and check that the host name and port settings are correct.");
        break;
    default:
        QTcpSocket* socket = qobject_cast<QTcpSocket*>(sender());
        QMessageBox::information(this, "QTCPServer", QString("The following error occurred: %1.").arg(socket->errorString()));
        break;
    }
}

void NetSID::displayMessage(const QString& str)
{
    ui->textBrowser_receivedMessages->append(str);
}

void NetSID::displayProgress(const int value)
{
    if (value == -1)
    {
        ui->bufferstate_progressBar->setMaximum(10);
        ui->bufferstate_progressBar->setValue(0);
        return;
    }

    if (value > ui->bufferstate_progressBar->maximum())
        ui->bufferstate_progressBar->setMaximum(value);

    ui->bufferstate_progressBar->setValue(value);
}
