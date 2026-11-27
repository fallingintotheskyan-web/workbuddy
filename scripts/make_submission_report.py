"""Generates the submission report (作品说明.docx) for the classroom-notes work."""

from __future__ import annotations

import sys
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.shared import Pt

FONT = "Microsoft YaHei"


def _set_font(run) -> None:
    run.font.name = FONT
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT)


def heading(doc: Document, text: str, level: int = 1) -> None:
    paragraph = doc.add_heading(text, level=level)
    for run in paragraph.runs:
        _set_font(run)


def body(doc: Document, text: str, style: str | None = None) -> None:
    paragraph = doc.add_paragraph(style=style) if style else doc.add_paragraph()
    run = paragraph.add_run(text)
    _set_font(run)


def bullet(doc: Document, text: str) -> None:
    body(doc, text, style="List Bullet")


def main(output: str) -> None:
    doc = Document()

    normal = doc.styles["Normal"]
    normal.font.name = FONT
    normal.font.size = Pt(10.5)
    normal.element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT)

    title = doc.add_heading("课堂速记 —— 课堂实时录音转写与翻译工具", level=0)
    for run in title.runs:
        _set_font(run)

    body(doc, "学号：2026250391014    姓名：李显亮    作品名：课堂速记")
    body(
        doc,
        "一句话介绍：上课时把老师说的话实时变成字幕，并可一键翻译成中文、英文或俄语，"
        "帮助外语课跟不上节奏的同学边听边看。",
    )

    heading(doc, "一页速览（主要信息）")
    bullet(doc, "痛点：听外语课时老师语速偏快、有口音，容易跟不上、断片，影响听课效果。")
    bullet(doc, "作品：课堂速记——手机实时录音转字幕（partial/final），可切换中/英/俄翻译，待机循环视频。")
    bullet(
        doc,
        "测试：真机发现 4 个问题（字幕延迟/断句、翻译不触发、视频横屏、录音未保存）并已修复；"
        "26 个客户端测试、8 个后端测试通过，并用真实英文语音做了端到端验证。",
    )
    bullet(
        doc,
        "部署：已部署到腾讯云 CloudBase，前端网页 "
        "https://educational-cheetah-d0bsf4e3c3a6-1527509554.tcloudbaseapp.com 可直接访问，"
        "后端 API / WebSocket 已上线（/health 返回 200）。",
    )
    bullet(doc, "AI：使用 DeepSeek Harness 生成代码、WorkBuddy 完成云端部署；我负责需求、真机测试与取舍。")
    doc.add_page_break()

    heading(doc, "一、我的痛点与本人决定")
    body(
        doc,
        "我的痛点：我在听外语课（英语、俄语等）时，老师语速偏快、有口音，"
        "经常听着听着就跟不上，一走神就断片，直接影响听课效果；课后想补笔记也补不回来。",
    )
    body(doc, "我的决定：做一个“边听边看”的工具，而不是又一个笔记软件：")
    bullet(doc, "手机端实时录音，边说边出字幕；没说完的是临时字幕（灰色斜体），停顿后锁定成正式句子。")
    bullet(doc, "可选的实时翻译：默认关闭，开启后可选中/英/俄作为目标语言，只翻译已经锁定的句子。")
    bullet(doc, "待机时播放课堂氛围视频，点“开始录音”进入字幕页，停止后回到待机页。")
    bullet(doc, "坚持最小可用：不做说话人分离、摘要、账号、云同步、端侧模型，控制成本和复杂度。")

    heading(doc, "二、作品说明（做了什么）")
    body(doc, "平台：Android 手机 + 电脑浏览器（Web 版），并已部署到云端。")
    body(doc, "核心功能：")
    bullet(doc, "实时转写：16kHz 单声道 PCM 音频 → WebSocket → Deepgram 流式识别 → partial/final 字幕。")
    bullet(doc, "静音处理：静音约 1.5 秒自动停止送音频并锁定当前句；恢复说话时回放约 300ms 预缓冲，避免吞首字。")
    bullet(doc, "翻译：默认关闭；开启后对 final 句子调用 DeepL，译文显示在原文下方，相同句子走缓存。")
    bullet(doc, "待机视频：全屏、循环、静音、无控制条；视频缺失时自动降级为渐变背景并给出提示。")
    bullet(doc, "录音留存：停止录音后把本次音频保存为 WAV，并在界面提示保存路径。")
    body(
        doc,
        "技术方案：Flutter（Android/Web 同一套代码）；后端 FastAPI + WebSocket；ASR 用 Deepgram，"
        "翻译用 DeepL；音频统一 16kHz/单声道/16-bit PCM；密钥只存在后端环境变量，客户端不含任何 Key。",
    )
    body(doc, "云端部署（WorkBuddy 完成）：")
    bullet(doc, "前端网页：https://educational-cheetah-d0bsf4e3c3a6-1527509554.tcloudbaseapp.com")
    bullet(doc, "后端 API：https://classroom-notes-api-343538-4-1527509554.sh.run.tcloudbase.com")
    bullet(doc, "WebSocket：wss://classroom-notes-api-343538-4-1527509554.sh.run.tcloudbase.com/ws/asr")
    bullet(doc, "健康检查：/health 返回 200（asrProvider=deepgram，translateProvider=deepl）。")
    bullet(doc, "前端通过 HTTPS 访问，浏览器可正常申请麦克风权限；API Key 只在云端后端。")

    heading(doc, "三、测试与改进证据")
    body(doc, "整个过程按“发现问题 → 定位原因 → 修复 → 复测”推进，证据见 截图/ 与 测试录像.mp4。")
    body(doc, "1. 第一轮真机测试（截图 01、02，录像 03）")
    bullet(
        doc,
        "发现 4 个问题：字幕延迟/断句、翻译不触发、待机视频横屏、录音去向不明。"
        "定位到 VAD 按“帧”计时（实际音频块是变长的）导致 1.5 秒静音判断被放大；改为按字节时长计时，"
        "并调整为“先开麦克风缓冲、再建连、连上回放 300ms”。",
    )
    bullet(doc, "翻译只对 final 调用，final 不锁定就不会翻译，修复 VAD 后恢复；录音改为停止时保存 WAV 并提示路径。")
    body(doc, "2. 转网页版（截图 04）")
    bullet(
        doc,
        "最初网页版拿不到麦克风 PCM，只能演示；后来确认 record 的 Web 后端可用 AudioWorklet 产出 16kHz PCM16，"
        "改为 Web 走真实录音链路。",
    )
    body(doc, "3. UI 重排（截图 05）")
    bullet(doc, "按手机相册播放横屏视频的样式重排：纯黑背景、视频居中 BoxFit.contain、上下分区，避免溢出。")
    body(doc, "4. 语言切换与乱码（截图 06、07）")
    bullet(
        doc,
        "发现切换到英文后仍输出乱码：原因是切换语言只改了界面，没有让识别流用新语言重开。"
        "修复为切换时重开 ASR 流并动态传 language；同时加了“调试录音”把发送给 ASR 的音频存成 WAV，"
        "亲自试听确认音频格式正常。",
    )
    body(doc, "5. 云端部署（截图 08）")
    bullet(
        doc,
        "本地版换到其他电脑无法使用，于是用 WorkBuddy 把前后端部署到腾讯云 CloudBase；"
        "部署后用真实英文语音验证：识别出“Today, we will”，并返回中文译文。",
    )
    body(
        doc,
        "自动化验证：Flutter analyze 0 问题；26 个客户端单元/Widget 测试通过；后端 8 个测试通过；"
        "APK 构建成功并安装到真机。",
    )

    heading(doc, "四、AI 使用与个人反思")
    body(doc, "使用的 AI：DeepSeek Harness（编码 Agent）+ WorkBuddy（云端部署）。")
    body(
        doc,
        "AI 做了什么：搭建 Flutter 工程、写界面与状态机、写 FastAPI 后端与 WebSocket 协议、写测试、"
        "构建 APK 并部署到真机；WorkBuddy 完成腾讯云部署。",
    )
    body(
        doc,
        "我做了什么：提出需求与验收标准；做产品取舍（例如否掉 speech_edge，因为它只返回识别文本、拿不到原始 PCM）；"
        "坚持翻译只翻 final、控制 API 成本；完成真机验收并整理问题反馈；确认 API Key 只放后端；"
        "督促 AI 保存调试音频并亲自试听，定位语言切换问题；最终完成云端部署。",
    )
    body(
        doc,
        "AI 披露：代码主要由 AI 生成，我逐项真机测试、复现问题并驱动修复；提交的客户端中没有任何 API Key。",
    )
    body(
        doc,
        "个人反思：这次做“课堂实时速记”App，我最大的感受是：用好 AI，比我一开始想象的要难太多了。"
        "中间无数次报错、卡壳，我甚至好几次都崩溃想放弃。",
    )
    body(
        doc,
        "一开始我以为，只要不停地把需求告诉 AI、对着产品一点点修改，它就能给我一个至少不算差的产品。"
        "但现实是，AI 很会“偷懒”（直接拿假数据糊弄我），也会“胡说八道”"
        "（明明底层音频数据都坏了，它还坚称参数完全正确）。"
        "这让我意识到，我不能只当甩手掌柜，得逐项去检查 AI 的每一步。"
        "我开始硬着头皮查报错日志，让它把录音存下来让我自己听。"
        "在这个过程中，我真正弄懂了声音是怎么从手机麦克风，一步步变成电脑上的文字的。",
    )
    body(
        doc,
        "从本地环境怎么也配不好，到连不上手机，再到最后硬着头皮把它部署到云端，我踩了无数个坑。"
        "这次作业让我明白，代码写出来只是第一步，怎么把它跑通、修好，才是最折磨也最锻炼人的。"
        "虽然过程很痛苦，但看到网页最后真的能对外访问，还是觉得挺有成就感的。感谢这次“折磨”，"
        "让我提前体验了真实的开发日常。",
    )

    doc.save(output)
    print(f"saved {output}")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else str(
        Path(__file__).resolve().parent.parent / "submission" / "课堂速记" / "作品说明.docx"
    )
    main(target)
