/* Copyright (C) 2011 The Android Open Source Project
**
** This software is licensed under the terms of the GNU General Public
** License version 2, as published by the Free Software Foundation, and
** may be copied, distributed, and modified under those terms.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
*/

#include "android/crashreport/ui/ConfirmDialog.h"

#include <QEventLoop>
#include <QFutureWatcher>
#include <QScrollBar>
#include <QSettings>
#include "QtConcurrent/qtconcurrentrun.h"

static const char kMessageBoxTitle[] = "Android Emulator";
static const char kMessageBoxMessageInternalError[] =
        "<p>Android Emulator closed because of an internal error:</p>";
static const char kMessageBoxMessage[] =
        "<p>Android Emulator closed unexpectedly.</p>";
static const char kMessageBoxMessageFooter[] =
        "<p>Do you want to send a crash report about the problem?</p>";
static const char kMessageBoxMessageDetailHW[] =
        "An error report containing the information shown below, "
        "including system-specific information, "
        "will be sent to Google's Android team to help identify "
        "and fix the problem. "
        "<a href=\"https://www.google.com/policies/privacy/\">Privacy "
        "Policy</a>.";

static const char kIconFile[] = "emulator_icon_128.png";

extern "C" const unsigned char* android_emulator_icon_find(const char* name,
                                                           size_t* psize);

ConfirmDialog::ConfirmDialog(QWidget* parent,
                             android::crashreport::CrashService* crashservice,
                             Ui::Settings::CRASHREPORT_PREFERENCE_VALUE reportPreference)
    : QDialog(parent),
      mCrashService(crashservice),
      mReportPreference(reportPreference),
      mDetailsHidden(true),
      mDidGetSysInfo(false),
      mDidUpdateDetails(false) {

    mSendButton = new QPushButton(tr("Send report"));
    mDontSendButton = new QPushButton(tr("Don't send"));
    mDetailsButton = new QPushButton(tr(""));
    mLabelText = new QLabel(QString::fromStdString(constructDumpMessage()));
    mInfoText = new QLabel(kMessageBoxMessageDetailHW);
    mIcon = new QLabel();
    mCommentsText = new QTextEdit();
    mDetailsText = new QPlainTextEdit();
    mProgressText = new QLabel(tr("Working..."));
    mProgress = new QProgressBar;
    mSavePreference =
        new QCheckBox(tr("Automatically send future crash reports "
                         "(Re-configure in emulator settings menu)"));
    QSettings settings;
    bool save_preference_checked =
        settings.value(Ui::Settings::CRASHREPORT_SAVEPREFERENCE_CHECKED, 1).toInt();
    mSavePreference->setChecked(save_preference_checked);
    mSavePreference->show();

    mSuggestionText = new QLabel(tr("Suggestion(s) based on crash info:\n\n"));
    mSuggestionText->setTextInteractionFlags(Qt::TextSelectableByMouse);

    mExtension = new QWidget;
    mYesNoButtonBox = new QDialogButtonBox(Qt::Horizontal);
    mDetailsButtonBox = new QDialogButtonBox(Qt::Horizontal);
    mComment = new QWidget;

    size_t icon_size;
    QPixmap icon;

    const unsigned char* icon_data =
            android_emulator_icon_find(kIconFile, &icon_size);

    icon.loadFromData(icon_data, icon_size);

    mIcon->setPixmap(icon);
    mSendButton->setDefault(true);
    mInfoText->setWordWrap(true);
    mInfoText->setOpenExternalLinks(true);
    mCommentsText->setPlaceholderText(
            tr("(Optional) Please describe what you were doing when the crash "
               "occured."));
    mDetailsText->setReadOnly(true);
    mProgressText->hide();
    mProgress->setRange(0, 0);
    mProgress->hide();

    crashservice->processCrash();
    auto suggestions = crashservice->getSuggestions().suggestions;
    if (!suggestions.empty()) {
        if (suggestions.find(
                    android::crashreport::Suggestion::UpdateGfxDrivers) !=
            suggestions.end()) {
#ifdef __APPLE__
            addSuggestion("This crash appears to be in your computer's graphics driver. Please check your\n"
                          "manufacturer's website for updated graphics drivers.\n\n"
                          "If problems persist, try using software rendering: uncheck \"Use Host GPU\"\n"
                          "in your AVD configuration.");
#else
            addSuggestion("This crash appears to be in your computer's graphics driver. Please check your\n"
                          "manufacturer's website for updated graphics drivers.\n\n"
                          "If problems persist, try using software rendering: add \"-gpu mesa\" to\n"
                          "the emulator command line, or uncheck \"Use Host GPU\" in your AVD configuration.");
#endif
        }
        mSuggestionText->show();
    } else {
        mSuggestionText->hide();
    }

    mYesNoButtonBox->addButton(mSendButton, QDialogButtonBox::AcceptRole);
    mYesNoButtonBox->addButton(mDontSendButton, QDialogButtonBox::RejectRole);
    mDetailsButtonBox->addButton(mDetailsButton, QDialogButtonBox::ActionRole);

    setWindowIcon(icon);
    connect(mSendButton, SIGNAL(clicked()), this, SLOT(sendReport()));
    connect(mDontSendButton, SIGNAL(clicked()), this, SLOT(dontSendReport()));
    connect(mDetailsButton, SIGNAL(clicked()), this, SLOT(detailtoggle()));

    QVBoxLayout* commentLayout = new QVBoxLayout;
    commentLayout->setMargin(0);
    commentLayout->addWidget(mCommentsText);
    mComment->setLayout(commentLayout);
    mComment->setMaximumHeight(
            QFontMetrics(mCommentsText->currentFont()).height() * 7);

    QVBoxLayout* extensionLayout = new QVBoxLayout;
    extensionLayout->setMargin(0);
    extensionLayout->addWidget(mDetailsText);

    mExtension->setLayout(extensionLayout);

    QGridLayout* mainLayout = new QGridLayout;

    QFrame* hLineFrame = new QFrame();
    hLineFrame->setFrameShape(QFrame::HLine);

    mainLayout->addWidget(mIcon, 0, 0);
    mainLayout->addWidget(mLabelText, 0, 1, 1, 2);

    mainLayout->addWidget(mSuggestionText, 1, 0, 1, 3);

    mainLayout->addWidget(hLineFrame, 2, 0, 1, 3);

    mainLayout->addWidget(mInfoText, 3, 0, 1, 3);

    mainLayout->addWidget(mComment, 4, 0, 1, 3);

    mainLayout->addWidget(mSavePreference, 5, 0, 1, 3);

    mainLayout->addWidget(mDetailsButtonBox, 6, 0, Qt::AlignLeft);
    mainLayout->addWidget(mYesNoButtonBox, 6, 1, 1, 2);

    mainLayout->addWidget(mExtension, 7, 0, 1, 3);

    mainLayout->addWidget(mProgressText, 8, 0, 1, 3);
    mainLayout->addWidget(mProgress, 9, 0, 1, 3);

    mainLayout->setSizeConstraint(QLayout::SetFixedSize);
    setLayout(mainLayout);
    setWindowTitle(tr(kMessageBoxTitle));
    hideDetails();
}

void ConfirmDialog::hideDetails() {
    mDetailsButton->setText(tr("Show details"));
    mDetailsText->hide();
    mDetailsHidden = true;
}

void ConfirmDialog::disableInput() {
    mSendButton->setEnabled(false);
    mDontSendButton->setEnabled(false);
    mDetailsButton->setEnabled(false);
    mCommentsText->setEnabled(false);
    mSavePreference->setEnabled(false);
}

void ConfirmDialog::enableInput() {
    mSendButton->setEnabled(true);
    mDontSendButton->setEnabled(true);
    mDetailsButton->setEnabled(true);
    mCommentsText->setEnabled(true);
    mSavePreference->setEnabled(true);
}

void ConfirmDialog::getDetails() {
    if (!mDidGetSysInfo) {
        disableInput();

        showProgressBar("Collecting crash info... this may take a minute.");
        QEventLoop eventloop;

        QFutureWatcher<bool> watcher;
        connect(&watcher, SIGNAL(finished()), &eventloop, SLOT(quit()));

        // Start the computation.
        QFuture<bool> future = QtConcurrent::run(
                mCrashService,
                &::android::crashreport::CrashService::collectSysInfo);
        watcher.setFuture(future);

        eventloop.exec();

        hideProgressBar();
        enableInput();
    }
    mDidGetSysInfo = true;
}

void ConfirmDialog::showDetails() {
    getDetails();
    if (!mDidUpdateDetails) {
        QString details = QString::fromStdString(mCrashService->getReport());
        details += QString::fromStdString(mCrashService->getSysInfo());

        mDetailsText->document()->setPlainText(details);
        mDidUpdateDetails = true;
    }

    mDetailsButton->setText(tr("Hide details"));
    mDetailsText->show();
    mDetailsText->verticalScrollBar()->setValue(
            mDetailsText->verticalScrollBar()->minimum());
    mDetailsHidden = false;
}

void ConfirmDialog::addSuggestion(const QString& str) {
    QString next_text = mSuggestionText->text() + str + "\n";
    mSuggestionText->setText(next_text);
}

bool ConfirmDialog::didGetSysInfo() const {
    return mDidGetSysInfo;
}

QString ConfirmDialog::getUserComments() {
    return mCommentsText->toPlainText();
}

void ConfirmDialog::showProgressBar(const std::string& msg) {
    mProgressText->setText(msg.c_str());
    mProgressText->show();
    mProgress->show();
}

void ConfirmDialog::hideProgressBar() {
    mProgressText->hide();
    mProgress->hide();
}

bool ConfirmDialog::uploadCrash() {
    disableInput();
    showProgressBar("Sending crash report...");
    QEventLoop eventloop;

    QFutureWatcher<bool> watcher;
    connect(&watcher, SIGNAL(finished()), &eventloop, SLOT(quit()));

    // Start the computation.
    QFuture<bool> future = QtConcurrent::run(
            mCrashService, &::android::crashreport::CrashService::uploadCrash);
    watcher.setFuture(future);

    eventloop.exec();

    hideProgressBar();

    return watcher.result();
}

static void savePref(bool checked, Ui::Settings::CRASHREPORT_PREFERENCE_VALUE v) {
    QSettings settings;
    settings.setValue(Ui::Settings::CRASHREPORT_PREFERENCE,
            checked ? v : Ui::Settings::CRASHREPORT_PREFERENCE_ASK);
    settings.setValue(Ui::Settings::CRASHREPORT_SAVEPREFERENCE_CHECKED,
                      checked);
}

void ConfirmDialog::sendReport() {
    getDetails();
    mCrashService->addUserComments(mCommentsText->toPlainText().toStdString());
    bool upload_success = uploadCrash();

    if (upload_success &&
        (mReportPreference == Ui::Settings::CRASHREPORT_PREFERENCE_ASK)) {
        QMessageBox msgbox(this);
        msgbox.setWindowTitle(tr("Crash Report Submitted"));
        msgbox.setText(tr("<p>Thank you for submitting a crash report!</p>"
                          "<p>If you would like to contact us for further information, "
                          "use the following Crash Report ID:</p>"));
        QString msg = QString::fromStdString(mCrashService->getReportId());
        msgbox.setInformativeText(msg);
        msgbox.setTextInteractionFlags(Qt::TextSelectableByMouse);
        msgbox.exec();
    }

    savePref(mSavePreference->isChecked(), Ui::Settings::CRASHREPORT_PREFERENCE_ALWAYS);
    accept();
}

void ConfirmDialog::dontSendReport() {
    reject();
}

void ConfirmDialog::detailtoggle() {
    if (mDetailsHidden) {
        showDetails();
    } else {
        hideDetails();
    }
}

std::string ConfirmDialog::constructDumpMessage() const {
    std::string dumpMessage = mCrashService->getDumpMessage();
    if (dumpMessage.empty()) {
        dumpMessage = kMessageBoxMessage;
    } else {
        dumpMessage = std::string(kMessageBoxMessageInternalError) + "<p>" +
                      dumpMessage + "</p>";
    }
    dumpMessage += kMessageBoxMessageFooter;
    return dumpMessage;
}