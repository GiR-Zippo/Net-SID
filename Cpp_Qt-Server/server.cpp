#include "server.h"

Server::Server()
{
    m_server = new QTcpServer();
    if(m_server->listen(QHostAddress::Any, 8080))
    {
        /*connect(this, &MainWindow::newMessage, this, &MainWindow::displayMessage);
        connect(m_server, &QTcpServer::newConnection, this, &MainWindow::newConnection);
        ui->statusBar->showMessage("Server is listening...");*/
    }
    else
    {
        QMessageBox::critical(NULL,"NetSID-Server",QString("Unable to start the server: %1.").arg(m_server->errorString()));
        exit(EXIT_FAILURE);
    }
}

