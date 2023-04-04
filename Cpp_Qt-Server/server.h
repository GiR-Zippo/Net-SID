#ifndef SERVER_H
#define SERVER_H

#include <QStandardPaths>
#include <QTcpServer>
#include <QTcpSocket>
#include <QMessageBox>

class Server
{
    private:
        // Private Constructor
        Server();
        // Stop the compiler generating methods of copy the object
        Server(Server const& copy);            // Not Implemented
        Server& operator=(Server const& copy); // Not Implemented

    public:
        static Server& getInstance()
        {
            // The only instance
            // Guaranteed to be lazy initialized
            // Guaranteed that it will be destroyed correctly
            static Server instance;
            return instance;
        }
    private:
        QTcpServer* m_server;
        QSet<QTcpSocket*> connection_set;
};

#endif // SERVER_H
