#ifndef MEMUTIL_H
#define MEMUTIL_H

#include <QDialog>
#include <QRandomGenerator>
#include <QMessageBox>

#include "memiocontroller.h"

namespace Ui {
class MemUtil;
}

class MemUtil : public QDialog
{
    Q_OBJECT

public:
    explicit MemUtil(QWidget *parent = nullptr);
    ~MemUtil();

private slots:
    void on_btnRandVid_pressed();

    void on_btnPokeVIDMODE_pressed();

    void on_btnChars_pressed();

    void on_comboBox_currentIndexChanged(int index);

    void on_comboBox_activated(int index);

    void on_btnShadowIO_toggled(bool checked);

    void on_btnRefresh_pressed();

    void on_btnPeek_pressed();

    void on_btnPoke_pressed();

    void on_btnSetShadow67_pressed();

    void on_btnSetShadow89_pressed();

    void on_btnSetShadowAB_pressed();

    void on_btnSetShadowCD_pressed();

    void on_btnShadowE4_toggled(bool checked);

    void on_btnWPZEROPAGE_toggled(bool checked);

    void on_btnWPE4ROM_toggled(bool checked);

    void on_btnWPX1CROM_toggled(bool checked);

    void on_btnDequeue_pressed();

    void on_btnClear_pressed();

    void on_btnColor_pressed();

    void on_btnCharout_pressed();

    void on_btnCH_pressed();

    void on_btnCV_pressed();

    void on_btnCLS_pressed();

    void on_btnRegister_pressed();

    void on_btnCursor_toggled(bool checked);

    void on_btnCR_pressed();

private:
    Ui::MemUtil *ui;
};

#endif // MEMUTIL_H
