# Design Document - やらかし共有掲示板

## Overview

やらかし共有掲示板は、ユーザーが失敗体験を匿名で共有し、他のユーザーが共感や学びを得られるWebアプリケーションです。Supabase中心のアーキテクチャを採用し、高速開発とスケーラビリティを両立します。

## Architecture

### システム構成
```
Frontend (Next.js) ←→ Supabase (PostgreSQL + Auth + Storage + Edge Functions)
```

### 技術スタック
- **Frontend**: Next.js 15.4.6 + React 19 + TypeScript + Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Database**: Supabase PostgreSQL with Row Level Security (RLS)
- **Storage**: Supabase Storage (画像アップロード)
- **Authentication**: Supabase Auth（匿名認証）
- **State Management**: TanStack React Query
- **Real-time**: Supabase Realtime（共感スタンプのリアルタイム更新）

## Components and Interfaces

### Frontend Components

#### Pages
- `/` - トップページ（投稿一覧）
- `/post/[id]` - 投稿詳細ページ
- `/create` - 投稿作成ページ
- `/category/[category]` - カテゴリ別投稿一覧
- `/search` - 検索結果ページ
- `/admin` - 管理者ページ

#### Core Components
```typescript
// 投稿関連
- PostCard: 投稿カードコンポーネント
- PostDetail: 投稿詳細表示
- PostForm: 投稿作成フォーム
- EmpathyStamps: 共感スタンプコンポーネント

// UI共通
- SearchBar: 検索バー
- CategoryFilter: カテゴリフィルター
- TagCloud: タグクラウド
- Pagination: ページネーション

// 管理機能
- ReportButton: 通報ボタン
- AdminPostList: 管理者用投稿一覧
```

### Supabase Operations

#### 投稿関連（直接データベース操作）
```typescript
// 投稿一覧取得
const { data } = await supabase
  .from('posts')
  .select('*, empathy_reactions(reaction_type)')
  .order('created_at', { ascending: false })

// 投稿作成
const { data } = await supabase
  .from('posts')
  .insert({ title, content, category, tags, image_url })

// 投稿検索
const { data } = await supabase
  .from('posts')
  .select('*')
  .textSearch('title,content', searchQuery)
```

#### 共感スタンプ（リアルタイム対応）
```typescript
// 共感スタンプ追加
const { error } = await supabase
  .from('empathy_reactions')
  .upsert({ post_id, reaction_type, user_session })

// リアルタイム購読
supabase
  .channel('empathy_reactions')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'empathy_reactions' }, 
      (payload) => updateUI(payload))
  .subscribe()
```

#### 画像アップロード
```typescript
// Supabase Storage使用
const { data } = await supabase.storage
  .from('post-images')
  .upload(`${postId}/${fileName}`, file)
```

#### Row Level Security (RLS) ポリシー
```sql
-- 投稿表示制御
CREATE POLICY "Show visible posts" ON posts 
FOR SELECT USING (is_hidden = false);

-- 管理者のみ削除可能
CREATE POLICY "Admin delete only" ON posts 
FOR DELETE USING (auth.jwt() ->> 'role' = 'admin');
```

## Data Models

### Posts Table
```sql
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    tags TEXT[], -- PostgreSQL array type
    image_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_hidden BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0
);
```

### Empathy Reactions Table
```sql
CREATE TABLE empathy_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL, -- 'understand', 'same_experience', 'cheer_up', 'learned'
    user_session VARCHAR(100) NOT NULL, -- 匿名セッションID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, reaction_type, user_session)
);
```

### Reports Table
```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    reason VARCHAR(100) NOT NULL,
    description TEXT,
    reporter_session VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Categories Table
```sql
CREATE TABLE categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0
);
```

## Error Handling

### Frontend Error Handling
- React Error Boundaries for component レベルエラー
- TanStack React Query の error handling
- Toast notifications for user feedback
- Fallback UI for network errors

### Backend Error Handling
```go
type APIError struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
    Details string `json:"details,omitempty"`
}

// Standard HTTP status codes
- 400: Bad Request (validation errors)
- 401: Unauthorized (admin access required)
- 404: Not Found (post not found)
- 429: Too Many Requests (rate limiting)
- 500: Internal Server Error
```

### Database Error Handling
- Connection pool management
- Transaction rollback on failures
- Constraint violation handling
- Graceful degradation for read operations

## Testing Strategy

### Frontend Testing
```typescript
// Unit Tests (Jest + React Testing Library)
- Component rendering tests
- User interaction tests
- Form validation tests
- API integration tests

// E2E Tests (Playwright)
- Post creation flow
- Search and filtering
- Empathy reaction flow
- Admin moderation flow
```

### Supabase Testing
```typescript
// Database Function Tests
- RLS policy tests
- Edge function tests
- Database trigger tests

// Integration Tests
- Supabase client integration tests
- Authentication flow tests
- Real-time subscription tests
```

### Database Testing
- Migration tests
- Constraint validation tests
- Performance tests for queries
- Data integrity tests

## Security Considerations

### 匿名性の保護
- セッションベースの匿名識別
- IPアドレスのハッシュ化
- 個人特定可能情報の除去

### Content Security
- XSS prevention (input sanitization)
- CSRF protection
- Rate limiting for API endpoints
- Image upload validation and scanning

### Data Privacy
- 最小限のデータ収集
- 定期的なデータクリーンアップ
- GDPR準拠のデータ処理

## Performance Optimization

### Frontend
- Next.js SSG/ISR for static content
- Image optimization with Next.js Image
- Code splitting and lazy loading
- React Query caching

### Supabase
- Built-in connection pooling
- PostgREST automatic query optimization
- Edge caching for static queries
- Built-in pagination support

### Database
```sql
-- Performance indexes
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
CREATE INDEX idx_empathy_post_id ON empathy_reactions(post_id);
```