# SSH鍵セットアップ自動化フロー 検討結果

## 提案されたフロー

1. ユーザーが Web UI にアクセス
2. フロントエンドが「SSH鍵セットアップAPI」を叩く
3. バックエンド側で
   - 鍵があれば → そのまま `status=exists`
   - なければ → 鍵を生成して `status=generated`
4. フロントはレスポンスを受けるまで
   - 「鍵を生成しています（初回のみ）」ローディング表示
5. 完了したら
   - 普通のトップ画面に遷移

## 既存コードの確認結果

### フロントエンド
- **エントリーポイント**: `app/page.tsx` - シンプルな構造
- **ローディングコンポーネント**: `components/loading.tsx` - 既に存在
- **API呼び出しパターン**: `app/_api/fetchGet.ts`, `fetchPost.ts` - 既存パターンあり
- **バックエンドURL取得**: `lib/getBackendUrl.ts` - 既存機能

### バックエンド
- **既存API**: `/api/sshkey` (GET) - 公開鍵取得のみ
- **SSH鍵パス**: `/app/config/.ssh/loghoi-key` (環境変数 `SSH_KEY_PATH` で変更可能)
- **鍵使用箇所**: `core/common.py` の `connect_ssh()` 関数

## 実装案

### 1. バックエンドAPI実装

#### 新しいエンドポイント: `GET /api/ssh-key/setup`

**設計方針**:
- GETメソッドを使用（冪等性を保つ）
- 鍵の存在確認と生成を1つのエンドポイントで完結
- 既存の `/api/sshkey` はそのまま維持（後方互換性）

**レスポンス形式**:
```json
{
  "status": "exists" | "generated",
  "data": {
    "public_key": "ssh-rsa AAAAB3...",
    "message": "SSH鍵が既に存在します" | "SSH鍵を生成しました"
  }
}
```

**実装ロジック**:
```python
@app.get("/api/ssh-key/setup")
async def ssh_key_setup() -> Dict[str, Any]:
    """
    SSH鍵セットアップAPI
    
    鍵が存在する場合はそのまま返し、存在しない場合は生成する。
    アプリ起動時に自動的に呼び出される。
    """
    key_file = os.getenv("SSH_KEY_PATH", "/app/config/.ssh/loghoi-key")
    pub_key_file = f"{key_file}.pub"
    key_dir = os.path.dirname(key_file)
    
    # 鍵が既に存在する場合
    if os.path.exists(key_file) and os.path.exists(pub_key_file):
        try:
            with open(pub_key_file, 'r') as f:
                public_key = f.read().strip()
            return {
                "status": "exists",
                "data": {
                    "public_key": public_key,
                    "message": "SSH鍵が既に存在します"
                }
            }
        except Exception as e:
            # 読み込みエラーの場合は再生成
            pass
    
    # 鍵が存在しない場合は生成
    try:
        # ディレクトリ作成
        os.makedirs(key_dir, mode=0o700, exist_ok=True)
        
        # SSH鍵生成（subprocessでssh-keygenを実行）
        import subprocess
        result = subprocess.run(
            [
                "ssh-keygen",
                "-t", "rsa",
                "-b", "4096",
                "-f", key_file,
                "-N", "",  # パスフレーズなし
                "-C", "loghoi@kubernetes"
            ],
            capture_output=True,
            text=True,
            check=True
        )
        
        # 権限設定
        os.chmod(key_file, 0o600)
        os.chmod(pub_key_file, 0o644)
        
        # 公開鍵を読み込んで返す
        with open(pub_key_file, 'r') as f:
            public_key = f.read().strip()
        
        return {
            "status": "generated",
            "data": {
                "public_key": public_key,
                "message": "SSH鍵を生成しました"
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"SSH鍵の生成に失敗しました: {str(e)}"
        )
```

**既存コードへの影響**:
- ✅ 新しいエンドポイントの追加のみ（既存コードへの変更なし）
- ✅ 既存の `/api/sshkey` はそのまま維持
- ✅ `connect_ssh()` 関数は変更不要（同じパスを使用）

### 2. フロントエンド実装

#### エントリーポイントの修正: `app/page.tsx`

**設計方針**:
- クライアントコンポーネントとして実装（`'use client'`）
- `useEffect`でアプリ起動時にAPIを呼び出す
- ローディング中は既存の`Loading`コンポーネントを表示
- 完了したら通常のトップ画面を表示

**実装案**:
```tsx
'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { Suspense } from 'react'

//api
import { getPclist } from './_api/pclist/getPclist'
import { getBackendUrl } from '@/lib/getBackendUrl'

//components
import Loading from '@/components/loading'
import PcRegist from '@/components/pcRegist'
import PcList from '@/components/pcList'

const Index = () => {
  const [isSetupComplete, setIsSetupComplete] = useState(false)
  const [setupStatus, setSetupStatus] = useState<'checking' | 'generating' | 'complete'>('checking')

  useEffect(() => {
    const setupSshKey = async () => {
      try {
        const backendUrl = getBackendUrl()
        const response = await fetch(`${backendUrl}/api/ssh-key/setup`, {
          method: 'GET',
        })
        
        if (response.ok) {
          const data = await response.json()
          if (data.status === 'generated') {
            setSetupStatus('generating')
            // 生成完了まで少し待つ（UX向上のため）
            await new Promise(resolve => setTimeout(resolve, 500))
          }
          setIsSetupComplete(true)
        } else {
          // エラーでも続行（既存の動作を維持）
          console.error('SSH鍵セットアップエラー:', response.statusText)
          setIsSetupComplete(true)
        }
      } catch (error) {
        // エラーでも続行（既存の動作を維持）
        console.error('SSH鍵セットアップエラー:', error)
        setIsSetupComplete(true)
      }
    }

    setupSshKey()
  }, [])

  // セットアップ完了前はローディング表示
  if (!isSetupComplete) {
    return (
      <main data-theme='white' className='relative flex text-center items-center h-screen'>
        <div className='absolute top-16 left-0 right-0 z-10'>
          <h1 className='text-6xl font-bold text-gray-700 tracking-wide drop-shadow-md'>
            Welcome to Log Hoihoi!
          </h1>
        </div>
        <Loading />
        {setupStatus === 'generating' && (
          <div className='absolute bottom-16 left-0 right-0 text-center'>
            <p className='text-lg text-gray-600'>
              SSH鍵を生成しています（初回のみ）...
            </p>
          </div>
        )}
      </main>
    )
  }

  // セットアップ完了後は通常のトップ画面
  return (
    <>
      <main data-theme='white' className='relative flex text-center items-center h-screen'>
        <div className='absolute top-16 left-0 right-0 z-10 pointer-events-none'>
          <h1 className='text-6xl font-bold text-gray-700 tracking-wide drop-shadow-md'>
            Welcome to Log Hoihoi!
          </h1>
        </div>
        <div className='w-1/2'>
          <Suspense fallback={<Loading />}>
            <PcList />
          </Suspense>
        </div>
        <PcRegist />
      </main>
    </>
  )
}

export default Index
```

**既存コードへの影響**:
- ⚠️ `app/page.tsx` をクライアントコンポーネントに変更（`'use client'`追加）
- ✅ 既存のコンポーネント（`PcList`, `PcRegist`, `Loading`）はそのまま使用
- ✅ 既存のAPI呼び出しパターン（`getBackendUrl()`）をそのまま使用

### 3. エラーハンドリング

**方針**:
- API呼び出しが失敗してもアプリは続行（既存の動作を維持）
- エラーはコンソールに出力（開発時のデバッグ用）
- ユーザーには通常のトップ画面を表示（既存の動作）

**理由**:
- 既存の動作を壊さないため
- 鍵が既に存在する場合はAPIが失敗しても問題ない
- 後で手動で鍵を設定することも可能

## 実装のメリット

### 1. 既存コードへの影響が最小限
- 新しいAPIエンドポイントの追加のみ
- 既存のAPIはそのまま維持
- 既存のコンポーネントはそのまま使用

### 2. 後方互換性
- 既存のデプロイ方法（`deploy.sh`など）はそのまま動作
- 既存の鍵管理方法もそのまま動作
- 新しい機能は追加のみ（既存機能への影響なし）

### 3. ユーザー体験の向上
- 初回アクセス時に自動的に鍵を生成
- ローディング表示で進行状況を明示
- エラー時もアプリは続行（既存の動作）

### 4. 実装の簡潔性
- 1つのAPIエンドポイントで完結
- フロントエンドの変更も最小限
- 既存のパターンをそのまま活用

## 実装の注意点

### 1. セキュリティ
- ✅ 秘密鍵は絶対にフロントエンドに送信しない
- ✅ 公開鍵のみをレスポンスに含める
- ✅ 鍵ファイルの権限を適切に設定（600, 644）

### 2. パフォーマンス
- 鍵生成は初回のみ（通常は即座にレスポンス）
- ローディング表示は最小限（500ms程度）
- エラー時も即座に続行

### 3. エラーハンドリング
- API呼び出し失敗時もアプリは続行
- 既存の動作を維持
- エラーはコンソールに出力（開発用）

## 実装の優先順位

### Phase 1: 基本実装（必須）
1. バックエンドAPI: `GET /api/ssh-key/setup`
2. フロントエンド: `app/page.tsx` の修正

### Phase 2: UX改善（推奨）
3. ローディングメッセージの改善
4. エラーメッセージの表示（オプション）

### Phase 3: 拡張機能（将来）
5. 鍵情報の表示（生成日時など）
6. 鍵の再生成機能
7. Prismへの登録案内

## 結論

提案されたフローは、**既存コードへの影響を最小限に抑えながら実装可能**です。

### 実装が必要な変更
1. **バックエンド**: 新しいAPIエンドポイント `GET /api/ssh-key/setup` の追加
2. **フロントエンド**: `app/page.tsx` をクライアントコンポーネントに変更し、起動時にAPIを呼び出す

### 既存コードへの影響
- ✅ 既存のAPIはそのまま維持
- ✅ 既存のコンポーネントはそのまま使用
- ✅ 既存のデプロイ方法はそのまま動作
- ✅ エラー時も既存の動作を維持

### 実装の難易度
- **低**: 既存のパターンをそのまま活用
- **工数**: バックエンド1エンドポイント + フロントエンド1ファイルの修正

この実装により、ユーザーは初回アクセス時に自動的にSSH鍵が生成され、スムーズにアプリを使用できるようになります。

