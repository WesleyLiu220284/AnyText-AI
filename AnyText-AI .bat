<# :
@echo off
:: 检查是否已经处于隐藏模式
if "%~1"=="hidden" goto :run_ps

:: 如果不是隐藏模式，生成一个临时的系统脚本，让它以"绝对不可见"的方式重启自己
echo Set wshShell = CreateObject("WScript.Shell") > "%temp%\hide_bat.vbs"
echo wshShell.Run """" ^& WScript.Arguments(0) ^& """" ^& " hidden", 0, False >> "%temp%\hide_bat.vbs"
cscript //nologo "%temp%\hide_bat.vbs" "%~f0"
del "%temp%\hide_bat.vbs"
exit /b

:run_ps
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Invoke-Expression ([System.IO.File]::ReadAllText('%~f0', [System.Text.Encoding]::UTF8))"
exit /b
#>

# 仅在开启时响一声“滴”，代表助手已就位，之后完全静音
[System.Media.SystemSounds]::Beep.Play()

Add-Type -AssemblyName System.Windows.Forms
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiKey = "YOUR_API_KEY_HERE"  # 请在此处填入你的智谱 API Key"
$lastText = ""

while ($true) {
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $currentText = [System.Windows.Forms.Clipboard]::GetText()
        
        if (![string]::IsNullOrWhiteSpace($currentText) -and $currentText -ne $lastText) {
            
            $lastText = $currentText
            
            try {
                $headers = @{
                    "Authorization" = "Bearer $apiKey"
                    "Content-Type"  = "application/json"
                }
                
                # 重新调教 AI：极其严苛的指令，针对选择、判断和简答做了硬性格式要求
                $prompt = "你是一个无情的考试答题机器。请直接给出最终答案，绝不包含任何多余的寒暄、解析或解释。如果是单选或多选（MCQ），直接给正确选项字母和内容；如果是判断题（True/False），直接回答正确或错误；如果是简答论述题，直接给出得分核心要点。题目如下：$currentText"
                
                $bodyObj = @{
                    model = "glm-4-flash"
                    messages = @(
                        @{
                            role = "user"
                            content = $prompt
                        }
                    )
                }
                
                $bodyJson = $bodyObj | ConvertTo-Json -Depth 3 -Compress
                $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)
                
                $response = Invoke-RestMethod -Uri "https://open.bigmodel.cn/api/paas/v4/chat/completions" `
                                              -Method Post `
                                              -Headers $headers `
                                              -Body $bodyBytes `
                                              -ContentType "application/json; charset=utf-8"
                                              
                $answer = $response.choices[0].message.content
                
                if (![string]::IsNullOrWhiteSpace($answer)) {
                    [System.Windows.Forms.Clipboard]::SetText($answer)
                    
                    # 再次读取剪贴板内容，彻底防止死循环
                    $lastText = [System.Windows.Forms.Clipboard]::GetText()
                }
            } catch {
                # 遇到问题保持沉默，等待下一道题
            }
        }
    }
    Start-Sleep -Seconds 1
}