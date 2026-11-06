/// High level state of a recording session, shown in the header pill.
enum SessionStatus {
  idle('待机'),
  connecting('连接中'),
  listening('正在听'),
  paused('已暂停'),
  reconnecting('网络不稳'),
  error('连接出错');

  const SessionStatus(this.label);

  final String label;
}
