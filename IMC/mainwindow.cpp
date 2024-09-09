#include "mainwindow.h"
#include "ui_mainwindow.h"

#include "memiocontroller.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    setGeometry(QStyle::alignedRect(Qt::LeftToRight, Qt::AlignCenter, size(), QGuiApplication::screens().front()->availableGeometry()));
    ui->screen->setFocus();
    statusLabel = new QLabel(ui->statusbar);
    ui->statusbar->addPermanentWidget(statusLabel);
    statusLabel->setText("Status Bar");

    // init memory buffer
    MemIOController::get().init();

    MemIOController& m = MemIOController::get();
    m.write(MemIOController::IOSTART + MemIOController::VID_MODE, 0x09);
    m.write(MemIOController::IOSTART + MemIOController::CON_COLOR, 0x5e);
    m.write(MemIOController::IOSTART + MemIOController::CON_CHAROUT, 0x20);
    m.write(MemIOController::IOSTART + MemIOController::CON_CURSOR, 0x80);
    m.write(MemIOController::IOSTART + MemIOController::CON_CLS, 0x80);
    auto l_pr = [&](const QString& a_str) {
        foreach (const QChar a, a_str) {
            m.write(MemIOController::IOSTART + MemIOController::CON_CHAROUT, a.toLatin1());
            m.write(MemIOController::IOSTART + MemIOController::CON_REGISTER, 0x80);
        }
    };
    l_pr("Interpreted Machine Console");
    m.write(MemIOController::IOSTART + MemIOController::CON_CR, 0x20);
    m.write(MemIOController::IOSTART + MemIOController::CON_COLOR, 0x5c);
    l_pr("By Stephen Sviatko");
    m.write(MemIOController::IOSTART + MemIOController::CON_CR, 0x20);
    l_pr("v0.8a - 25/Dec/2022");
    m.write(MemIOController::IOSTART + MemIOController::CON_CR, 0x20);
    m.write(MemIOController::IOSTART + MemIOController::CON_CR, 0x20);
    m.write(MemIOController::IOSTART + MemIOController::CON_COLOR, 0x5e);
    l_pr("Ready.");
    m.write(MemIOController::IOSTART + MemIOController::CON_CR, 0x20);
}

MainWindow::~MainWindow()
{
    delete ui;
    MemIOController::get().teardown();
}


void MainWindow::on_actionExit_triggered()
{
    QApplication::exit(0);
}

void MainWindow::on_actionMemory_Utilities_triggered()
{
    if (m_memutil == nullptr)
        m_memutil = new MemUtil(this);
    m_memutil->show();
    m_memutil->raise();
    m_memutil->activateWindow();
}
