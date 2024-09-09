#include "memutil.h"
#include "ui_memutil.h"

MemUtil::MemUtil(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::MemUtil)
{
    ui->setupUi(this);
    on_btnRefresh_pressed();
}

MemUtil::~MemUtil()
{
    delete ui;
}

void MemUtil::on_btnRandVid_pressed()
{
    for (quint32 i = MemIOController::VIDSTART; i <= MemIOController::VIDEND; ++i) {
        quint32 l_random = QRandomGenerator::system()->generate();
        quint8 l_byte = l_random & 0xff;
        MemIOController::get().write(i, l_byte);
    }
}

void MemUtil::on_btnPokeVIDMODE_pressed()
{
    bool l_ok = false;
    quint32 l_byte = ui->leVIDMODE->text().toInt(&l_ok, 16);
    if (!l_ok || (l_byte > 0xff)) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnChars_pressed()
{
    quint8 l_forecolor;
    quint8 l_backcolor;
    quint8 l_char = 0x00;
    for (quint32 i = MemIOController::VIDSTART; i <= MemIOController::VIDEND; i += 2) {
        l_forecolor = QRandomGenerator::system()->generate() & 0x0f;
        l_backcolor = QRandomGenerator::system()->generate() & 0x0f;
        quint8 l_poke = (l_backcolor << 4) + l_forecolor;
        // write character
        MemIOController::get().write(i, l_char);
        // write color info into second byte
        MemIOController::get().write(i + 1, l_poke);
        ++l_char;
    }
}

void MemUtil::on_comboBox_currentIndexChanged(int index)
{
    switch (index) {
    case 0:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 0);
        break;
    case 1:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 1);
        break;
    case 2:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 2);
        break;
    case 3:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 4);
        break;
    case 4:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 5);
        break;
    case 5:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 6);
        break;
    case 6:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 8);
        break;
    case 7:
        MemIOController::get().write(MemIOController::IOSTART + MemIOController::VID_MODE, 9);
        break;
    }
    on_btnRefresh_pressed();
}

void MemUtil::on_comboBox_activated(int index)
{
    on_comboBox_currentIndexChanged(index);
}

void MemUtil::on_btnShadowIO_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_IO, l_val);
}


void MemUtil::on_btnRefresh_pressed()
{
    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_IO) > 127) {
        ui->btnShadowIO->setChecked(true);
    } else {
        ui->btnShadowIO->setChecked(false);
    }
    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_E4) > 127) {
        ui->btnShadowE4->setChecked(true);
    } else {
        ui->btnShadowE4->setChecked(false);
    }
    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::WP_ZEROPAGE) > 127) {
        ui->btnWPZEROPAGE->setChecked(true);
    } else {
        ui->btnWPZEROPAGE->setChecked(false);
    }
    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::WP_E400_ROM) > 127) {
        ui->btnWPE4ROM->setChecked(true);
    } else {
        ui->btnWPE4ROM->setChecked(false);
    }
    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::WP_X1C_ROM) > 127) {
        ui->btnWPX1CROM->setChecked(true);
    } else {
        ui->btnWPX1CROM->setChecked(false);
    }
    quint8 l_vidmode = MemIOController::get().read(MemIOController::IOSTART + MemIOController::VID_MODE);
    ui->leVIDMODE->setText(QString("00" + QString::number(l_vidmode, 16)).right(2));
    switch (l_vidmode) {
    case 0:
        ui->comboBox->setCurrentIndex(0);
        break;
    case 1:
        ui->comboBox->setCurrentIndex(1);
        break;
    case 2:
        ui->comboBox->setCurrentIndex(2);
        break;
    case 4:
        ui->comboBox->setCurrentIndex(3);
        break;
    case 5:
        ui->comboBox->setCurrentIndex(4);
        break;
    case 6:
        ui->comboBox->setCurrentIndex(5);
        break;
    case 8:
        ui->comboBox->setCurrentIndex(6);
        break;
    case 9:
        ui->comboBox->setCurrentIndex(7);
        break;
    default:
    {
        if (l_vidmode > 7)
            ui->comboBox->setCurrentIndex(6);
        else
            ui->comboBox->setCurrentIndex(0);
    }
        break;
    }

    // blocked, for your protection
    {
        quint32 l_shadow67 = MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_67);
        quint32 l_shadow67address = l_shadow67 << 13;
        ui->leShadow67->setText(QString("00" + QString::number(l_shadow67, 16)).right(2));
        if (l_shadow67 > 7) {
            ui->leShadow67Address->setText(QString("00000000" + QString::number(l_shadow67address, 16)).right(8));
        } else {
            ui->leShadow67Address->setText("default");
        }
    }
    {
        quint32 l_shadow89 = MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_89);
        quint32 l_shadow89address = l_shadow89 << 13;
        ui->leShadow89->setText(QString("00" + QString::number(l_shadow89, 16)).right(2));
        if (l_shadow89 > 7) {
            ui->leShadow89Address->setText(QString("00000000" + QString::number(l_shadow89address, 16)).right(8));
        } else {
            ui->leShadow89Address->setText("default");
        }
    }
    {
        quint32 l_shadowAB = MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_AB);
        quint32 l_shadowABaddress = l_shadowAB << 13;
        ui->leShadowAB->setText(QString("00" + QString::number(l_shadowAB, 16)).right(2));
        if (l_shadowAB > 7) {
            ui->leShadowABAddress->setText(QString("00000000" + QString::number(l_shadowABaddress, 16)).right(8));
        } else {
            ui->leShadowABAddress->setText("default");
        }
    }
    {
        quint32 l_shadowCD = MemIOController::get().read(MemIOController::IOSTART + MemIOController::SHADOW_CD);
        quint32 l_shadowCDaddress = l_shadowCD << 13;
        ui->leShadowCD->setText(QString("00" + QString::number(l_shadowCD, 16)).right(2));
        if (l_shadowCD > 7) {
            ui->leShadowCDAddress->setText(QString("00000000" + QString::number(l_shadowCDaddress, 16)).right(8));
        } else {
            ui->leShadowCDAddress->setText("default");
        }
    }
    quint8 l_keyq_size = MemIOController::get().read(MemIOController::IOSTART + MemIOController::KEYQ_SIZE);
    ui->leSize->setText(QString("00" + QString::number(l_keyq_size, 16)).right(2));
    quint8 l_keyq_waiting = MemIOController::get().read(MemIOController::IOSTART + MemIOController::KEYQ_WAITING);
    ui->leWaiting->setText(QString("00" + QString::number(l_keyq_waiting, 16)).right(2));
    quint8 l_con_color = MemIOController::get().read(MemIOController::IOSTART + MemIOController::CON_COLOR);
    ui->leColor->setText(QString("00" + QString::number(l_con_color, 16)).right(2));
    quint8 l_con_charout = MemIOController::get().read(MemIOController::IOSTART + MemIOController::CON_CHAROUT);
    ui->leCharout->setText(QString("00" + QString::number(l_con_charout, 16)).right(2));
    quint8 l_con_cursorh = MemIOController::get().read(MemIOController::IOSTART + MemIOController::CON_CURSORH);
    ui->leCH->setText(QString("00" + QString::number(l_con_cursorh, 16)).right(2));
    quint8 l_con_cursorv = MemIOController::get().read(MemIOController::IOSTART + MemIOController::CON_CURSORV);
    ui->leCV->setText(QString("00" + QString::number(l_con_cursorv, 16)).right(2));

    if (MemIOController::get().read(MemIOController::IOSTART + MemIOController::CON_CURSOR) > 127) {
        ui->btnCursor->setChecked(true);
    } else {
        ui->btnCursor->setChecked(false);
    }
}

void MemUtil::on_btnPeek_pressed()
{
    bool l_ok = false;
    quint32 l_addr = ui->lePPAddress->text().toUInt(&l_ok, 16);

    // remove memory bounds checking for now
//    if ((!l_ok) || (l_addr >= 16777216)) {
//        QMessageBox::warning(this, "Invalid Address", "Please enter a hexadecimal number between 0 and FFFFFF.", QMessageBox::Ok);
//        return;
//    }

    quint8 l_byte = MemIOController::get().read(l_addr);

    ui->lePPAddress->setText(QString("00000000" + QString::number(l_addr, 16)).right(8));
    ui->lePPByte->setText(QString("00" + QString::number(l_byte, 16)).right(2));
    ui->lePPAddress->setFocus();
    ui->lePPAddress->selectAll();
}

void MemUtil::on_btnPoke_pressed()
{
    bool l_ok = false;
    quint32 l_addr = ui->lePPAddress->text().toInt(&l_ok, 16);

//    if ((!l_ok) || (l_addr >= 16777216)) {
//        QMessageBox::warning(this, "Invalid Address", "Please enter a hexadecimal number between 0 and FFFFFF.", QMessageBox::Ok);
//        return;
//    }

    quint8 l_byte = ui->lePPByte->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
//    qDebug() << "Writing to address" << l_addr << "value" << l_byte;
    MemIOController::get().write(l_addr, l_byte);

//    l_addr &= 0xffffff;
    ui->lePPAddress->setText(QString("00000000" + QString::number(l_addr, 16)).right(8));
    ui->lePPByte->setFocus();
    ui->lePPByte->selectAll();
    on_btnRefresh_pressed();
}

void MemUtil::on_btnSetShadow67_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leShadow67->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_67, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnSetShadow89_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leShadow89->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_89, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnSetShadowAB_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leShadowAB->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_AB, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnSetShadowCD_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leShadowCD->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_CD, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnShadowE4_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::SHADOW_E4, l_val);
}

void MemUtil::on_btnWPZEROPAGE_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::WP_ZEROPAGE, l_val);
}

void MemUtil::on_btnWPE4ROM_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::WP_E400_ROM, l_val);
}

void MemUtil::on_btnWPX1CROM_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::WP_X1C_ROM, l_val);
}

void MemUtil::on_btnDequeue_pressed()
{
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::KEYQ_DEQUEUE, 0x80);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnClear_pressed()
{
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::KEYQ_CLEAR, 0x80);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnColor_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leColor->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_COLOR, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnCharout_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leCharout->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CHAROUT, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnCH_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leCH->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CURSORH, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnCV_pressed()
{
    bool l_ok = false;
    quint8 l_byte = ui->leCV->text().toUInt(&l_ok, 16);

    if (!l_ok) {
        QMessageBox::warning(this, "Invalid Byte Value", "Please enter a hexadecimal number between 0 and FF.", QMessageBox::Ok);
        return;
    }
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CURSORV, l_byte);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnCLS_pressed()
{
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CLS, 0x80);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnRegister_pressed()
{
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_REGISTER, 0x80);
    on_btnRefresh_pressed();
}

void MemUtil::on_btnCursor_toggled(bool checked)
{
    quint8 l_val = checked ? 0x80 : 0x00;
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CURSOR, l_val);
}

void MemUtil::on_btnCR_pressed()
{
    MemIOController::get().write(MemIOController::IOSTART + MemIOController::CON_CR, 0x80);
    on_btnRefresh_pressed();
}
