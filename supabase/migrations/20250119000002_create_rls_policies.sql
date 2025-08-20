-- やらかし共有掲示板 - RLSポリシー実装
-- 作成日: 2025-01-19

-- RLSを有効化
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE empathy_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- カテゴリテーブル: 全員が読み取り可能
CREATE POLICY "Categories are viewable by everyone" ON categories
    FOR SELECT USING (true);

-- 投稿テーブルのポリシー
-- 1. 非表示でない投稿は全員が閲覧可能
CREATE POLICY "Show visible posts" ON posts
    FOR SELECT USING (is_hidden = false);

-- 2. 匿名ユーザーは投稿作成可能
CREATE POLICY "Anonymous users can create posts" ON posts
    FOR INSERT WITH CHECK (true);

-- 3. 管理者のみ投稿を更新可能（非表示化など）
CREATE POLICY "Admin can update posts" ON posts
    FOR UPDATE USING (
        (auth.jwt() ->> 'role')::text = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

-- 4. 管理者のみ投稿を削除可能
CREATE POLICY "Admin can delete posts" ON posts
    FOR DELETE USING (
        (auth.jwt() ->> 'role')::text = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

-- 共感リアクションテーブルのポリシー
-- 1. 全員がリアクションを閲覧可能
CREATE POLICY "Empathy reactions are viewable by everyone" ON empathy_reactions
    FOR SELECT USING (true);

-- 2. 匿名ユーザーはリアクション追加可能
CREATE POLICY "Anonymous users can add empathy reactions" ON empathy_reactions
    FOR INSERT WITH CHECK (true);

-- 3. 同一セッションのユーザーは自分のリアクションを削除可能
CREATE POLICY "Users can delete their own reactions" ON empathy_reactions
    FOR DELETE USING (
        user_session = COALESCE(
            (auth.jwt() ->> 'sub')::text,
            auth.uid()::text
        )
    );

-- 通報テーブルのポリシー
-- 1. 管理者のみ通報を閲覧可能
CREATE POLICY "Admin can view reports" ON reports
    FOR SELECT USING (
        (auth.jwt() ->> 'role')::text = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

-- 2. 匿名ユーザーは通報作成可能
CREATE POLICY "Anonymous users can create reports" ON reports
    FOR INSERT WITH CHECK (true);

-- 3. 管理者のみ通報ステータスを更新可能
CREATE POLICY "Admin can update reports" ON reports
    FOR UPDATE USING (
        (auth.jwt() ->> 'role')::text = 'admin' OR 
        (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

-- セキュリティ関数: 匿名ユーザーのセッションIDを取得
CREATE OR REPLACE FUNCTION get_user_session()
RETURNS TEXT AS $$
BEGIN
    -- 匿名ユーザーの場合はauth.uid()を使用
    -- 未認証の場合はNULLを返す
    RETURN auth.uid()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 共感リアクションの重複防止制約を強化
-- 既存のUNIQUE制約に加えて、アプリケーションレベルでも制御

-- コメント追加
COMMENT ON POLICY "Show visible posts" ON posts IS '非表示でない投稿のみ表示';
COMMENT ON POLICY "Anonymous users can create posts" ON posts IS '匿名ユーザーの投稿作成を許可';
COMMENT ON POLICY "Admin can update posts" ON posts IS '管理者のみ投稿更新可能';
COMMENT ON POLICY "Admin can delete posts" ON posts IS '管理者のみ投稿削除可能';
COMMENT ON POLICY "Empathy reactions are viewable by everyone" ON empathy_reactions IS '全員がリアクション閲覧可能';
COMMENT ON POLICY "Anonymous users can add empathy reactions" ON empathy_reactions IS '匿名ユーザーのリアクション追加を許可';
COMMENT ON POLICY "Users can delete their own reactions" ON empathy_reactions IS '自分のリアクションのみ削除可能';
COMMENT ON POLICY "Admin can view reports" ON reports IS '管理者のみ通報閲覧可能';
COMMENT ON POLICY "Anonymous users can create reports" ON reports IS '匿名ユーザーの通報作成を許可';
COMMENT ON POLICY "Admin can update reports" ON reports IS '管理者のみ通報更新可能';