'use client'
import { useState, useEffect } from 'react'
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
