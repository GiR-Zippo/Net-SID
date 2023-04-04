
#ifndef NETSID_H
#define NETSID_H

#include <QMainWindow>
#include <QDebug>
#include <QFile>
#include <QFileDialog>
#include <QMessageBox>
#include <QMetaType>
#include <QSet>
#include <QStandardPaths>
#include <QTcpServer>
#include <QTcpSocket>
#include "Serial.h"

QT_BEGIN_NAMESPACE
namespace Ui { class NetSID; }
QT_END_NAMESPACE

class NetSID : public QMainWindow

{
    Q_OBJECT

public:
    NetSID(QWidget *parent = nullptr);
    ~NetSID();

signals:
    void newMessage(QString);
    void bufProgress(int value);

private slots:
    void panicClicked();

    void newConnection();
    void appendToSocketList(QTcpSocket* socket);

    void readSocket();
    void discardSocket();
    void displayError(QAbstractSocket::SocketError socketError);

    void displayMessage(const QString& str);
    void displayProgress(const int value);

private:
    Ui::NetSID *ui;
    QTcpServer* m_server;
    QSet<QTcpSocket*> connection_set;
    Serial *_serial;
};

#endif // NETSID_H
