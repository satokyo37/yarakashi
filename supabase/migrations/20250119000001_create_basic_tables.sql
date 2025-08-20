-- やらかし共有掲示板 - 基本テーブル作成
-- 作成日: 2025-01-19

-- カテゴリテーブル
CREATE TABLE categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 投稿テーブル
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) NOT NULL REFERENCES categories(id),
    tags TEXT[], -- PostgreSQL array type
    image_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_hidden BOOLEAN DEFAULT FALSE,
    view_count INTEGER DEFAULT 0
);

-- 共感リアクションテーブル
CREATE TABLE empathy_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL, -- 'understand', 'same_experience', 'cheer_up', 'learned'
    user_session VARCHAR(100) NOT NULL, -- 匿名セッションID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, reaction_type, user_session)
);

-- 通報テーブル
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    reason VARCHAR(100) NOT NULL,
    description TEXT,
    reporter_session VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- パフォーマンス向上のためのインデックス作成
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
CREATE INDEX idx_posts_is_hidden ON posts(is_hidden);
CREATE INDEX idx_empathy_post_id ON empathy_reactions(post_id);
CREATE INDEX idx_empathy_reaction_type ON empathy_reactions(reaction_type);
CREATE INDEX idx_reports_post_id ON reports(post_id);
CREATE INDEX idx_reports_status ON reports(status);

-- 更新日時の自動更新トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON posts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 基本カテゴリデータの挿入
INSERT INTO categories (id, name, description, display_order) VALUES
    ('work', '仕事', '職場でのやらかしエピソード', 1),
    ('daily', '日常', '日常生活でのうっかりミス', 2),
    ('travel', '旅行', '旅行先でのハプニング', 3),
    ('love', '恋愛', '恋愛関係でのやらかし', 4),
    ('study', '勉強', '学習・資格取得でのミス', 5),
    ('money', 'お金', '金銭管理でのやらかし', 6),
    ('health', '健康', '健康管理でのうっかり', 7),
    ('technology', 'テクノロジー', 'IT・デジタル関連のミス', 8),
    ('cooking', '料理', '料理・食事でのやらかし', 9),
    ('other', 'その他', 'その他のやらかしエピソード', 10);

-- コメント追加
COMMENT ON TABLE categories IS 'やらかしのカテゴリ分類';
COMMENT ON TABLE posts IS 'やらかし投稿';
COMMENT ON TABLE empathy_reactions IS '投稿への共感リアクション';
COMMENT ON TABLE reports IS '不適切な投稿の通報';