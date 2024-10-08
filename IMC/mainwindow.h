#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QLabel>
#include <QStyle>
#include <QScreen>

#include "memutil.h"

QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void on_actionExit_triggered();

    void on_actionMemory_Utilities_triggered();

private:
    Ui::MainWindow *ui;
    QLabel *statusLabel;
    MemUtil *m_memutil = nullptr;
};
#endif // MAINWINDOW_H
