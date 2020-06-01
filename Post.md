
# 通过mach thread捕获任意线程调用栈信息-Swift

# 前言

通过mach thread捕获任意线程调用栈的Swift库，[BacktraceSwift](https://github.com/FengDeng/Backtrace)

保持和原生Api一样的输出信息。结尾有两种输出的对比。

使用姿势：

```swift
import BacktraceSwift
BacktraceSwift.backtrace(thread: Thread)->String
BacktraceSwift.backtraceMainThread()->String
BacktraceSwift.backtraceCurrentThread()->String
BacktraceSwift.backtraceAllThread()->[String]
```

最近在做iOS DoraemonKit的Swift化工作。[DoraemonKit](https://github.com/didi/DoraemonKit)简称 "DoKit" 。一款功能齐全的客户端（ iOS 、Android、微信小程序 ）研发助手，你值得拥有

像这种性能监控工具，不免常常需要获取线程的调用栈，用来分析性能瓶颈，崩溃原因等等。于是有了该文。

打个广告：

[招募DoKit纯Swift版本共建者，赢纪念T恤](https://github.com/didi/DoraemonKit/issues/493)

[招募DoKit纯Swift版本共建者，赢纪念T恤](https://github.com/didi/DoraemonKit/issues/493)

[招募DoKit纯Swift版本共建者，赢纪念T恤](https://github.com/didi/DoraemonKit/issues/493)

# 1. 什么是线程调用栈

简单的来说，就是存放当前线程的调用函数信息的地方。它们以一种栈的结构进行存储，方便函数往下调用，往上返回。

下面的解释纯属copy:


![](https://user-gold-cdn.xitu.io/2020/6/1/1726ba3d2bdaa869?w=1200&h=986&f=png&s=529090)

上图表示了一个栈，它分为若干栈帧(frame)，每个栈帧对应一个函数调用，比如蓝色的部分是 `DrawSquare` 函数的栈帧，它在执行的过程中调用了 `DrawLine` 函数，栈帧用绿色表示。

可以看到栈帧由三部分组成: 函数参数，返回地址，帧内的变量。举个例子，在调用 `DrawLine` 函数时首先把函数的参数入栈，这是第一部分；随后将返回地址入栈，这表示当前函数执行完后回到哪里继续执行；在函数内部定义的变量则属于第三部分。

`Stack Pointer(栈指针)`表示当前栈的顶部，由于大部分操作系统的栈向下生长，它其实是栈地址的最小值。根据之前的解释，`Frame Pointer` 指向的地址中，存储了上一次 `Stack Pointer` 的值，也就是返回地址。

在大多数操作系统中，每个栈帧还保存了上一个栈帧的 `Frame Pointer`，因此只要知道当前栈帧的 `Stack Pointer` 和 `Frame Pointer`，就能知道上一个栈帧的 `Stack Pointer` 和 `Frame Pointer`，从而递归的获取栈底的帧。

显然当一个函数调用结束时，它的栈帧就不存在了。

因此，调用栈其实是栈的一种抽象概念，它表示了方法之间的调用关系，一般来说从栈中可以解析出调用栈。

# 2. 为什么我们需要线程调用栈信息

开发调试。需要堆栈信息

APP又崩溃了，快去给我看看。 需要堆栈信息

给我做性能调优！有时候需要堆栈信息

```swift
没有通过分析堆栈解决不了的程序问题，如果有，那就再分析一遍！
--来自一位不愿透露姓名的程序员
```

# 3. 如何获取线程调用栈

系统提供了函数`Thread.callstackSymbols`

完结！

可惜天不遂人愿，`Thread.callstackSymbols`只能获取当前线程的堆栈信息。而我们大多数时候需要获取其他线程的堆栈信息，主线程的堆栈信息，甚至所有线程的堆栈信息。这个系统方法就无效了。

那么有没有办法获取所有线程的堆栈信息呢？

两个思路：

- signal
- mach thread

由于`Backtrace` 就是通过该种方式获取iOS所有线程调用栈信息的。所以本文主要讲通过内核线程，也就是`mach thread`获取所有线程堆栈信息。

# 通过内核线程获取所有线程调用栈

1. `mach` 提供一个系统方法，该方法可以获取当前进程的所有线程

```swift
public func task_threads(_ target_task: task_inspect_t, _ act_list: UnsafeMutablePointer<thread_act_array_t?>!, _ act_listCnt: UnsafeMutablePointer<mach_msg_type_number_t>!) -> kern_return_t
```

这样，所有的线程我们已经拿到了，接下来我们需要分别拿到他们的调用栈信息

2. 好巧不巧，`mach` 又提供了一个方法，该方法可以获取任意线程的`thread_state_t`信息

```swift
public func thread_get_state(_ target_act: thread_act_t, _ flavor: thread_state_flavor_t, _ old_state: thread_state_t!, _ old_stateCnt: UnsafeMutablePointer<mach_msg_type_number_t>!) -> kern_return_t
```

3. 再利用`thread_state_t`信息，拿到当前线程里每个函数的指针

```c
int df_backtrace(thread_t thread, void** stack, int maxSymbols) {
    _STRUCT_MCONTEXT machineContext;
    mach_msg_type_number_t stateCount = THREAD_STATE_COUNT;
    kern_return_t kret = thread_get_state(thread, THREAD_STATE_FLAVOR, (thread_state_t)&(machineContext.__ss), &stateCount);
    if (kret != KERN_SUCCESS) {
        return 0;
    }
    int i = 0;
#if defined(__arm__) || defined (__arm64__)
    stack[i] = (void *)machineContext.__ss.__lr;
    ++i;
#endif
    void **currentFramePointer = (void **)machineContext.__ss.__framePointer;
    while (i < maxSymbols && currentFramePointer) {
        void **previousFramePointer = *currentFramePointer;
        if (!previousFramePointer){
            break;
        }
        stack[i] = *(currentFramePointer+1);
        currentFramePointer = previousFramePointer;
        ++i;
    }
    return i;
}
```

4. 利用系统的`backtrace_symbols`，传入上一步拿到的指针，获取到符号信息。

```swift
func backtrace_symbols(_ stack: UnsafePointer<UnsafeMutableRawPointer?>!, _ frame: Int32) -> UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>!
```

5. 完结撒花

# 生活不是一帆风顺,只想获取某个线程的调用栈

我不想要所有的线程调用栈信息，我只想获取某个线程的调用栈信息。我给你一个Thread实例，你告诉我调用栈信息！

纳尼？ 

Thread实例无法获取 thread_state_t`信息，也没有接口可以获取`callstackSymbols`

简单！看下面的转化路径

```swift
thread → pthread → mach thread
```

翻遍了github，google，只有`pthread → mach thread`，没有 `thread → pthread`,这条是断头路。

那么有没有办法了呢，如果把转化思路反过来呢？

我竟然已经获取到了所有的`mach thread`,那你的`thread`一定对应在里面。我只要找到对应你的`mach thread`不就行了吗？

可惜`mach thread`没有任何能够关联到`thread`的地方，通过系统api，我们知道`pthread`和`mach thread`可以互相转化。

```swift
public func pthread_mach_thread_np(_: pthread_t) -> mach_port_t
public func pthread_from_mach_thread_np(_: mach_port_t) -> pthread_t?
```

那么`pthread`有没有能和`mach thread`关联的地方呢？

[BSBacktraceLogger](https://github.com/bestswifter/BSBacktraceLogger)的作者[bestswifter](https://github.com/bestswifter)`提供了一种方法，那就是`name`

```swift
//for Thread
class Thread: NSObject {
    @available(iOS 2.0, *)
    open var name: String?
}

//for pthread
@available(iOS 3.2, *)
public func pthread_getname_np(_: pthread_t, _: UnsafeMutablePointer<Int8>, _: Int) -> Int32

@available(iOS 3.2, *)
public func pthread_setname_np(_: UnsafePointer<Int8>) -> Int32
```

现在只需要给 `thread`设置一个name，然后遍历所有的`mach thread`，如果名字相同，那么就可以确定该`mach thread`对应实例`thread`了。确定了`mach thread`，我们就可以获取到调用栈信息了。
```
    let originName = thread.name
    defer {
        thread.name = originName
    }
    let newName = String(Int(Date.init().timeIntervalSince1970))
    thread.name = newName
    for i in 0..<count {
        let machThread = threads[Int(i)]
        if let p_thread = pthread_from_mach_thread_np(machThread) {
            var name: [Int8] = Array<Int8>(repeating: 0, count: 128)
            pthread_getname_np(p_thread, &name, name.count)
            if thread.name == String(cString: name) {
                return machThread
            }
        }
    }
```

等等，还有一个问题，那就是主线程设置name竟然没有效果，坑爹啊！

我看其他的库都采用在+load里，或者让使用者在主线程调用相应的方法，用来获取`main_thread_t`。

在+load里还好，但是让使用者主动调用，不免有点坑。本来这个库的初衷是纯swift,已经引用的c文件，这里根本不想使用OC的+load。

我这里在获取主线程对应的`mach thread`做了点判断，如果没有`main_thread_t`的时候，同步到主线程去拿一下。

```swift
/// 如果当前线程不是主线程，但是需要获取主线程的堆栈
    if !Thread.isMainThread && thread.isMainThread  && main_thread_t == nil {
        DispatchQueue.main.sync {
            main_thread_t = mach_thread_self()
        }
        return main_thread_t ?? mach_thread_self()
    }
```

根据`thread`实例找到`mach thread`的方法如下：

```swift
/**
    这里主要利用了Thread 和 pThread 共用一个Name的特性，找到对应 thread的内核线程thread_t
    但是主线程不行，主线程设置Name无效.
 */
public var main_thread_t: mach_port_t?
fileprivate func machThread(from thread: Thread) -> thread_t {
    var count: mach_msg_type_number_t = 0
    var threads: thread_act_array_t!
    
    guard task_threads(mach_task_self_, &(threads), &count) == KERN_SUCCESS else {
        return mach_thread_self()
    }

    /// 如果当前线程不是主线程，但是需要获取主线程的堆栈
    if !Thread.isMainThread && thread.isMainThread  && main_thread_t == nil {
        DispatchQueue.main.sync {
            main_thread_t = mach_thread_self()
        }
        return main_thread_t ?? mach_thread_self()
    }
    
    let originName = thread.name
    defer {
        thread.name = originName
    }
    let newName = String(Int(Date.init().timeIntervalSince1970))
    thread.name = newName
    for i in 0..<count {
        let machThread = threads[Int(i)]
        if let p_thread = pthread_from_mach_thread_np(machThread) {
            var name: [Int8] = Array<Int8>(repeating: 0, count: 128)
            pthread_getname_np(p_thread, &name, name.count)
            if thread.name == String(cString: name) {
                return machThread
            }
        }
    }
    return mach_thread_self()
}
```

# 真的完结了!

如果有需要，欢迎品尝：[Backtrace]([https://github.com/FengDeng/Backtrace](https://github.com/FengDeng/Backtrace))

下面系统Api和Backtrace Api获取调用栈信息的日志，删除backtrace自身的调用，一模一样。

Thread.callStackSymbols:
```
0   Backtrace_Example                   0x0000000108e42a7d $s17Backtrace_Example11AppDelegateC11application_29didFinishLaunchingWithOptionsSbSo13UIApplicationC_SDySo0k6LaunchJ3KeyaypGSgtF + 269
1   Backtrace_Example                   0x0000000108e42fc3 $s17Backtrace_Example11AppDelegateC11application_29didFinishLaunchingWithOptionsSbSo13UIApplicationC_SDySo0k6LaunchJ3KeyaypGSgtFTo + 211
2   UIKitCore                           0x00007fff48c82698 -[UIApplication _handleDelegateCallbacksWithOptions:isSuspended:restoreState:] + 232
3   UIKitCore                           0x00007fff48c84037 -[UIApplication _callInitializationDelegatesWithActions:forCanvas:payload:fromOriginatingProcess:] + 3985
4   UIKitCore                           0x00007fff48c89bf9 -[UIApplication _runWithMainScene:transitionContext:completion:] + 1226
5   UIKitCore                           0x00007fff4839225d -[_UISceneLifecycleMultiplexer completeApplicationLaunchWithFBSScene:transitionContext:] + 122
6   UIKitCore                           0x00007fff4889dcc1 _UIScenePerformActionsWithLifecycleActionMask + 83
7   UIKitCore                           0x00007fff48392d6f __101-[_UISceneLifecycleMultiplexer _evalTransitionToSettings:fromSettings:forceExit:withTransitionStore:]_block_invoke + 198
8   UIKitCore                           0x00007fff4839277e -[_UISceneLifecycleMultiplexer _performBlock:withApplicationOfDeactivationReasons:fromReasons:] + 296
9   UIKitCore                           0x00007fff48392b9c -[_UISceneLifecycleMultiplexer _evalTransitionToSettings:fromSettings:forceExit:withTransitionStore:] + 818
10  UIKitCore                           0x00007fff48392431 -[_UISceneLifecycleMultiplexer uiScene:transitionedFromState:withTransitionContext:] + 345
11  UIKitCore                           0x00007fff48396a22 __186-[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:]_block_invoke_2 + 178
12  UIKitCore                           0x00007fff487b3dad +[BSAnimationSettings(UIKit) tryAnimatingWithSettings:actions:completion:] + 852
13  UIKitCore                           0x00007fff488bc41e _UISceneSettingsDiffActionPerformChangesWithTransitionContext + 240
14  UIKitCore                           0x00007fff4839673d __186-[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:]_block_invoke + 153
15  UIKitCore                           0x00007fff488bc321 _UISceneSettingsDiffActionPerformActionsWithDelayForTransitionContext + 84
16  UIKitCore                           0x00007fff483965ab -[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:] + 381
17  UIKitCore                           0x00007fff481eafa8 __64-[UIScene scene:didUpdateWithDiff:transitionContext:completion:]_block_invoke + 657
18  UIKitCore                           0x00007fff481e9b67 -[UIScene _emitSceneSettingsUpdateResponseForCompletion:afterSceneUpdateWork:] + 253
19  UIKitCore                           0x00007fff481eacd2 -[UIScene scene:didUpdateWithDiff:transitionContext:completion:] + 210
20  UIKitCore                           0x00007fff48c88141 -[UIApplication workspace:didCreateScene:withTransitionContext:completion:] + 512
21  UIKitCore                           0x00007fff487da8dc -[UIApplicationSceneClientAgent scene:didInitializeWithEvent:completion:] + 361
22  FrontBoardServices                  0x00007fff36cacd2e -[FBSSceneImpl _callOutQueue_agent_didCreateWithTransitionContext:completion:] + 419
23  FrontBoardServices                  0x00007fff36cd2dc1 __86-[FBSWorkspaceScenesClient sceneID:createWithParameters:transitionContext:completion:]_block_invoke.154 + 102
24  FrontBoardServices                  0x00007fff36cb7757 -[FBSWorkspace _calloutQueue_executeCalloutFromSource:withBlock:] + 220
25  FrontBoardServices                  0x00007fff36cd2a52 __86-[FBSWorkspaceScenesClient sceneID:createWithParameters:transitionContext:completion:]_block_invoke + 355
26  libdispatch.dylib                   0x0000000109b6de8e _dispatch_client_callout + 8
27  libdispatch.dylib                   0x0000000109b70da2 _dispatch_block_invoke_direct + 300
28  FrontBoardServices                  0x00007fff36cf86e9 __FBSSERIALQUEUE_IS_CALLING_OUT_TO_A_BLOCK__ + 30
29  FrontBoardServices                  0x00007fff36cf83d7 -[FBSSerialQueue _queue_performNextIfPossible] + 441
30  FrontBoardServices                  0x00007fff36cf88e6 -[FBSSerialQueue _performNextFromRunLoopSource] + 22
31  CoreFoundation                      0x00007fff23da0d31 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 17
32  CoreFoundation                      0x00007fff23da0c5c __CFRunLoopDoSource0 + 76
33  CoreFoundation                      0x00007fff23da0434 __CFRunLoopDoSources0 + 180
34  CoreFoundation                      0x00007fff23d9b02e __CFRunLoopRun + 974
35  CoreFoundation                      0x00007fff23d9a944 CFRunLoopRunSpecific + 404
36  GraphicsServices                    0x00007fff38ba6c1a GSEventRunModal + 139
37  UIKitCore                           0x00007fff48c8b9ec UIApplicationMain + 1605
38  Backtrace_Example                   0x0000000108e43648 main + 72
39  libdyld.dylib                       0x00007fff51a231fd start + 1
```
BacktraceSwift.backtraceMainThread():前5条是BacktraceSwift调用
```
0   libsystem_kernel.dylib              0x00007fff51b61ae7 thread_get_state + 405
1   Backtrace                           0x00000001090b1ead df_backtrace + 93
2   Backtrace                           0x00000001090b3d6b $s9Backtrace9backtrace33_B82A8C0ED7C904841114FDF244F9E58ELL1tSSs6UInt32V_tF + 283
3   Backtrace                           0x00000001090b21bd $s9Backtrace9backtrace6threadSSSo8NSThreadC_tF + 493
4   Backtrace                           0x00000001090b4107 $s9Backtrace19backtraceMainThreadSSyF + 55
5   Backtrace_Example                   0x0000000108e42c9b $s17Backtrace_Example11AppDelegateC11application_29didFinishLaunchingWithOptionsSbSo13UIApplicationC_SDySo0k6LaunchJ3KeyaypGSgtF + 811
6   Backtrace_Example                   0x0000000108e42fc3 $s17Backtrace_Example11AppDelegateC11application_29didFinishLaunchingWithOptionsSbSo13UIApplicationC_SDySo0k6LaunchJ3KeyaypGSgtFTo + 211
7   UIKitCore                           0x00007fff48c82698 -[UIApplication _handleDelegateCallbacksWithOptions:isSuspended:restoreState:] + 232
8   UIKitCore                           0x00007fff48c84037 -[UIApplication _callInitializationDelegatesWithActions:forCanvas:payload:fromOriginatingProcess:] + 3985
9   UIKitCore                           0x00007fff48c89bf9 -[UIApplication _runWithMainScene:transitionContext:completion:] + 1226
10  UIKitCore                           0x00007fff4839225d -[_UISceneLifecycleMultiplexer completeApplicationLaunchWithFBSScene:transitionContext:] + 122
11  UIKitCore                           0x00007fff4889dcc1 _UIScenePerformActionsWithLifecycleActionMask + 83
12  UIKitCore                           0x00007fff48392d6f __101-[_UISceneLifecycleMultiplexer _evalTransitionToSettings:fromSettings:forceExit:withTransitionStore:]_block_invoke + 198
13  UIKitCore                           0x00007fff4839277e -[_UISceneLifecycleMultiplexer _performBlock:withApplicationOfDeactivationReasons:fromReasons:] + 296
14  UIKitCore                           0x00007fff48392b9c -[_UISceneLifecycleMultiplexer _evalTransitionToSettings:fromSettings:forceExit:withTransitionStore:] + 818
15  UIKitCore                           0x00007fff48392431 -[_UISceneLifecycleMultiplexer uiScene:transitionedFromState:withTransitionContext:] + 345
16  UIKitCore                           0x00007fff48396a22 __186-[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:]_block_invoke_2 + 178
17  UIKitCore                           0x00007fff487b3dad +[BSAnimationSettings(UIKit) tryAnimatingWithSettings:actions:completion:] + 852
18  UIKitCore                           0x00007fff488bc41e _UISceneSettingsDiffActionPerformChangesWithTransitionContext + 240
19  UIKitCore                           0x00007fff4839673d __186-[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:]_block_invoke + 153
20  UIKitCore                           0x00007fff488bc321 _UISceneSettingsDiffActionPerformActionsWithDelayForTransitionContext + 84
21  UIKitCore                           0x00007fff483965ab -[_UIWindowSceneFBSSceneTransitionContextDrivenLifecycleSettingsDiffAction _performActionsForUIScene:withUpdatedFBSScene:settingsDiff:fromSettings:transitionContext:lifecycleActionType:] + 381
22  UIKitCore                           0x00007fff481eafa8 __64-[UIScene scene:didUpdateWithDiff:transitionContext:completion:]_block_invoke + 657
23  UIKitCore                           0x00007fff481e9b67 -[UIScene _emitSceneSettingsUpdateResponseForCompletion:afterSceneUpdateWork:] + 253
24  UIKitCore                           0x00007fff481eacd2 -[UIScene scene:didUpdateWithDiff:transitionContext:completion:] + 210
25  UIKitCore                           0x00007fff48c88141 -[UIApplication workspace:didCreateScene:withTransitionContext:completion:] + 512
26  UIKitCore                           0x00007fff487da8dc -[UIApplicationSceneClientAgent scene:didInitializeWithEvent:completion:] + 361
27  FrontBoardServices                  0x00007fff36cacd2e -[FBSSceneImpl _callOutQueue_agent_didCreateWithTransitionContext:completion:] + 419
28  FrontBoardServices                  0x00007fff36cd2dc1 __86-[FBSWorkspaceScenesClient sceneID:createWithParameters:transitionContext:completion:]_block_invoke.154 + 102
29  FrontBoardServices                  0x00007fff36cb7757 -[FBSWorkspace _calloutQueue_executeCalloutFromSource:withBlock:] + 220
30  FrontBoardServices                  0x00007fff36cd2a52 __86-[FBSWorkspaceScenesClient sceneID:createWithParameters:transitionContext:completion:]_block_invoke + 355
31  libdispatch.dylib                   0x0000000109b6de8e _dispatch_client_callout + 8
32  libdispatch.dylib                   0x0000000109b70da2 _dispatch_block_invoke_direct + 300
33  FrontBoardServices                  0x00007fff36cf86e9 __FBSSERIALQUEUE_IS_CALLING_OUT_TO_A_BLOCK__ + 30
34  FrontBoardServices                  0x00007fff36cf83d7 -[FBSSerialQueue _queue_performNextIfPossible] + 441
35  FrontBoardServices                  0x00007fff36cf88e6 -[FBSSerialQueue _performNextFromRunLoopSource] + 22
36  CoreFoundation                      0x00007fff23da0d31 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 17
37  CoreFoundation                      0x00007fff23da0c5c __CFRunLoopDoSource0 + 76
38  CoreFoundation                      0x00007fff23da0434 __CFRunLoopDoSources0 + 180
39  CoreFoundation                      0x00007fff23d9b02e __CFRunLoopRun + 974
40  CoreFoundation                      0x00007fff23d9a944 CFRunLoopRunSpecific + 404
41  GraphicsServices                    0x00007fff38ba6c1a GSEventRunModal + 139
42  UIKitCore                           0x00007fff48c8b9ec UIApplicationMain + 1605
43  Backtrace_Example                   0x0000000108e43648 main + 72
44  libdyld.dylib
```
## 参考文章

[BSBacktraceLogger](https://github.com/bestswifter/BSBacktraceLogger)

[RCBacktrace](https://github.com/woshiccm/RCBacktrace)

[ReadFoundationSource](https://github.com/whiteath/ReadFoundationSource)
