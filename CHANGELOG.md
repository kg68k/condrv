# 1.09c+17 (2024-12-11)

仕様変更
* 停止レベルの既定の最大値を1に変更(`-g`オプションで従来と同じ65535になる)。
* 組み込み時のオプション`-g`を、システムステータスの停止レベル表示から、
  停止レベル最大値を65535に設定する機能に変更した。
* 停止レベルが1以上のときシステムステータスにその値を表示していたが、
  キー操作によるバッファリング停止時は'!'を優先して表示するようにした。

不具合修正
* システムコール`$0023`(バッファリング履歴制御)の不具合を修正。
  * POPでスタックが空のときにエラーにならない。
  * POPでスタックが空でないときエラーになる。
  * PUSHで32回目がエラーになる。
* 組み込み時にバックログを初期化してC-↓でウィンドウを開くと不正なログを
  表示する不具合を修正。

機能追加
* 組み込み時にバックログを初期化しなかった場合、水平線を記録するようにした。


# 1.09c+16 (2023-08-27)

* テキスト同時アクセス有効時にウィンドウを開いても表示が乱れないように改善。

