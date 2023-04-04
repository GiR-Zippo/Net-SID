
#ifndef SERVERCOMMANDS_H
#define SERVERCOMMANDS_H

#include <QByteArray>

class ServerCommands
{
    public:
        ServerCommands();
        static QByteArray CreateOk();
        static QByteArray CreateBusy();
        static QByteArray CreateOk(quint8 msg);

        static QByteArray CreateVersion(quint8 msg);

        static QByteArray CreateConfigCount(quint8 msg);
        static QByteArray CreateConfigInfo(quint8 sidnum);

};

#endif // SERVERCOMMANDS_H
