
#include "netsid.h"

#include <QApplication>


int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    NetSID w;
    w.show();
    return a.exec();
}
