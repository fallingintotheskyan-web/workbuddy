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
        "26 个客户端测试、8 个后端测试通过。",
    )
    bullet(doc, "AI：使用 DeepSeek Harness 生成代码，我负责需求、真机验收与取舍；客户端不含任何 API Key。")
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
    bullet(doc, "待机时全屏循环播放课堂氛围视频，点“开始录音”进入字幕页，停止后回到待机页。")
    bullet(doc, "坚持最小可用：不做说话人分离、摘要、账号、云同步、端侧模型，控制成本和复杂度。")

    heading(doc, "二、作品说明（做了什么）")
    body(doc, "平台：Android 手机 + 电脑浏览器（Web 版，本次提交的 index.html）。")
    body(doc, "核心功能：")
    bullet(doc, "实时转写：16kHz 单声道 PCM 音频 → WebSocket → Deepgram 流式识别 → partial/final 字幕。")
    bullet(doc, "静音处理：静音约 1.5 秒自动停止送音频并锁定当前句；恢复说话时回放约 300ms 预缓冲，避免吞首字。")
    bullet(doc, "翻译：默认关闭；开启后对 final 句子调用 DeepL，译文显示在原文下方，相同句子走缓存。")
    bullet(doc, "待机视频：全屏、循环、静音、无控制条；视频缺失时自动降级为渐变背景并给出提示。")
    bullet(doc, "录音留存：停止录音后把本次音频保存为 WAV，并在界面提示保存路径。")
    body(doc, "技术方案：Flutter（Android/Web 同一套代码）；后端 FastAPI + WebSocket；ASR 用 Deepgram，"
              "翻译用 DeepL；音频统一 16kHz/单声道/16-bit PCM；密钥只存在后端 .env，客户端不含任何 Key。")
    body(
        doc,
        "网页版说明：提交的 index.html 为“演示模式”（内置演示字幕），不依赖后端即可打开、点击、看到完整交互；"
        "真实识别需要启动后端并配置自己的 Deepgram/DeepL Key，源码与运行说明已一并附上（源码/ 目录）。",
    )

    heading(doc, "三、测试与改进证据")
    body(doc, "真机测试截图见 截图/01-手机待机页.png，问题记录见 截图/02-测试问题记录.jpg，测试录像见 截图/03-测试录像.mp4。")
    body(doc, "第一轮真机测试发现 4 个问题，并逐项修复：")
    bullet(
        doc,
        "字幕慢、停顿不锁定、状态不显示“已暂停”。原因：VAD 按“帧”计时，而麦克风插件输出的是变长音频块"
        "（128ms 被当成 20ms），导致 1.5 秒静音判断被放大成数秒。修复：改为按字节时长计时；先开麦克风缓冲再建连，"
        "连上后回放 300ms 预缓冲。",
    )
    bullet(
        doc,
        "翻译不生效。根因同上：翻译只在 final 上触发，final 不锁定就永远不会翻译；修复后补了服务端翻译日志，"
        "确认开启时才调用、关闭时零调用。",
    )
    bullet(
        doc,
        "待机视频横向。源视频是 1280×720 横屏且没有旋转元数据；修复：Android 锁定竖屏，并在配置里支持 rotation 纠正方向。",
    )
    bullet(doc, "录音去向不明。修复：录音同时落盘，停止时生成 WAV 并提示“录音已保存至：路径”。")
    body(
        doc,
        "改进后的自测结果：Flutter analyze 0 问题；26 个客户端单元/Widget 测试通过；后端 8 个测试通过；"
        "APK 构建成功并安装到真机；用真实 Deepgram / DeepL Key 完成端到端验证（识别出中文、翻译返回译文）。",
    )

    heading(doc, "四、AI 使用与个人反思")
    body(doc, "使用的 AI：DeepSeek Harness（编码 Agent）。")
    body(doc, "AI 做了什么：搭建 Flutter 工程骨架、写界面与状态机、写 FastAPI 后端与 WebSocket 协议、"
              "写测试、构建 APK 并部署到真机、根据我的反馈定位并修复问题。")
    body(doc, "我做了什么：提出需求与验收标准；做产品取舍（例如否掉 speech_edge，因为它只返回识别文本、"
              "拿不到原始 PCM）；坚持翻译只翻 final、控制 API 成本；完成真机验收并整理 4 个 Bug 反馈；"
              "确认 API Key 只放后端、客户端不含密钥；确认视频方向与页面布局。")
    body(
        doc,
        "AI 披露：代码主要由 AI 生成，我逐项真机测试、复现问题并驱动修复；提交的客户端中没有任何 API Key。",
    )
    body(
        doc,
        "个人反思：AI 能很快产出“理论上完整”的工程，但真机上的时序、权限、方向、网络问题只有实测才暴露。"
        "这次让我更重视可验证的验收清单，也意识到 VAD、流式协议、跨平台差异这些底层概念自己还需要继续学习。",
    )

    doc.save(output)
    print(f"saved {output}")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else str(
        Path(__file__).resolve().parent.parent / "submission" / "课堂速记" / "作品说明.docx"
    )
    main(target)
