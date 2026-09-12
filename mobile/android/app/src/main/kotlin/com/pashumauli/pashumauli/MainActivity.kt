package com.pashumauli.pashumauli

import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
  private val channelName = "org.pashumauli/local_llm"
  private val modelFileName = "Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm"
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private var engine: Engine? = null
  private var conversation: Conversation? = null
  private var eventSink: EventChannel.EventSink? = null
  @Volatile private var status = "NOT_INSTALLED"
  @Volatile private var reason: String? = null

  private fun modelFile(): File = File(getExternalFilesDir(null) ?: filesDir, "models/$modelFileName")
  private fun info(): Map<String, Any?> = mapOf("name" to "Gemma 3 1B IT", "version" to "Gemma3-1B-IT multi-prefill q4 ekv4096", "runtime" to "LiteRT-LM 0.17.0", "backend" to "CPU", "status" to status, "reason" to reason, "localPath" to modelFile().absolutePath)

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "initialize", "initializeModel" -> initialize(result)
        "isAvailable" -> result.success(status == "READY")
        "modelInfo", "modelStatus" -> result.success(info())
        "sendMessage", "generate" -> generate(call.argument<String>("message"), result)
        "cancelGeneration", "cancel" -> { conversation?.cancelProcess(); status = "READY"; eventSink?.success(mapOf("type" to "cancelled")); result.success(null) }
        "dispose", "unload" -> { cleanup(); result.success(null) }
        else -> result.notImplemented()
      }
    }
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$channelName/stream").setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
      override fun onCancel(arguments: Any?) { eventSink = null }
    })
  }

  private fun initialize(result: MethodChannel.Result) {
    if (engine?.isInitialized() == true) { status = "READY"; result.success(info()); return }
    val file = modelFile()
    if (!file.isFile || file.length() <= 0L) { status = "NOT_INSTALLED"; reason = "Model not found in the app model directory."; result.success(info()); return }
    status = "LOADING"; reason = null; result.success(info())
    executor.execute {
      try {
        val started = System.nanoTime()
        engine = Engine(EngineConfig(modelPath = file.absolutePath, backend = Backend.CPU(), cacheDir = cacheDir.absolutePath)).also { it.initialize() }
        conversation = engine!!.createConversation()
        status = "READY"; reason = "Loaded in ${((System.nanoTime() - started) / 1_000_000)} ms"
        eventSink?.success(mapOf("type" to "status", "status" to status, "info" to info()))
      } catch (t: Throwable) {
        Log.e("PashuMauliLLM", "LiteRT-LM initialization failed", t)
        cleanup(); status = "ERROR"; reason = "Model could not be loaded: ${t.javaClass.simpleName}"
        eventSink?.success(mapOf("type" to "error", "code" to "MODEL_LOAD_FAILED", "message" to reason))
      }
    }
  }

  private fun generate(message: String?, result: MethodChannel.Result) {
    val active = conversation
    if (active == null || status != "READY") { result.error("MODEL_UNAVAILABLE", reason ?: "Model is not ready", info()); return }
    if (message.isNullOrBlank()) { result.error("INVALID_PROMPT", "A message is required", null); return }
    status = "GENERATING"; result.success(null)
    active.sendMessageAsync(message, object : MessageCallback {
      override fun onMessage(message: Message) { eventSink?.success(mapOf("type" to "token", "text" to message.toString())) }
      override fun onDone() { status = "READY"; eventSink?.success(mapOf("type" to "done")) }
      override fun onError(throwable: Throwable) { Log.e("PashuMauliLLM", "Generation failed", throwable); status = "ERROR"; reason = "Generation failed: ${throwable.javaClass.simpleName}"; eventSink?.success(mapOf("type" to "error", "code" to "GENERATION_FAILED", "message" to reason)) }
    })
  }

  private fun cleanup() { try { conversation?.close() } catch (_: Throwable) {}; conversation = null; try { engine?.close() } catch (_: Throwable) {}; engine = null; if (status != "ERROR") status = "NOT_INSTALLED" }
  override fun onDestroy() { cleanup(); executor.shutdownNow(); super.onDestroy() }
}
