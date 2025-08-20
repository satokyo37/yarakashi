---
inclusion: fileMatch
fileMatchPattern: '*.tsx'
---

# React コンポーネント開発ルール

## コンポーネント設計
- 単一責任の原則に従う
- propsの型定義を必須とする
- デフォルトpropsは避け、デフォルト値は分割代入で設定する
- 'use client'ディレクティブを適切に使用する

## 状態管理
- ローカル状態はuseStateを使用
- サーバー状態はTanStack React Queryを使用
- グローバル状態はContextを使用

## パフォーマンス
- 不要な再レンダリングを避ける
- useMemo、useCallbackを適切に使用
- 大きなリストにはvirtualizationを検討

## エラーハンドリング
- Error Boundaryを適切に配置
- ユーザーフレンドリーなエラーメッセージを表示
- ローディング状態を適切に管理

## アクセシビリティ
- セマンティックなHTMLを使用
- ARIA属性を適切に設定
- キーボードナビゲーションをサポート