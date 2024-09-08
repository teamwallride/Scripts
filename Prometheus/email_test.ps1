$sendMailMessageSplat = @{
    From = "prometheus@lab.com"
    To = "ant@bsd1"
    Subject = "PowerShell test email"
	Body = "Write heaps of stuff here..."
	SmtpServer = "bsd1"
}
Send-MailMessage @sendMailMessageSplat