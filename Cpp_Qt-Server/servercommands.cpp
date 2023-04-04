
#include "servercommands.h"
#include "Enums.h"

ServerCommands::ServerCommands()
{

}

QByteArray ServerCommands::CreateOk()
{
    QByteArray outData;
    outData.append(OK);
    return outData;
}

QByteArray ServerCommands::CreateBusy()
{
    QByteArray outData;
    outData.append(BUSY);
    return outData;
}

QByteArray ServerCommands::CreateOk(quint8 msg)
{
    QByteArray outData;
    outData.append(OK);
    outData.append(msg);
    return outData;
}

QByteArray ServerCommands::CreateVersion(quint8 msg)
{
    QByteArray outData;
    outData.append(VERSION);
    outData.append(msg);
    return outData;
}

QByteArray ServerCommands::CreateConfigCount(quint8 msg)
{
    QByteArray outData;
    outData.append(COUNT);
    outData.append(msg);
    return outData;
}

QByteArray ServerCommands::CreateConfigInfo(quint8 sidnum)
{
    QByteArray outData;
    outData.append(INFO);
    outData.append(sidnum);

    if (sidnum == 0)
    {
        std::string id = "HybridSID 6581 \0x00";
        outData.append(id.c_str());
    }
    else if (sidnum == 1)
    {
        std::string id = "HybridSID 8580 \0x00";
        outData.append(id.c_str());
    }
    return outData;
}



