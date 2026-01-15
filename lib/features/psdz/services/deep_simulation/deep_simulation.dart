/// Deep Simulation Library
/// BMW ECU Deep Simulation System
///
/// Complete simulation of BMW vehicle ECUs with authentic responses
/// Compatible with E-Sys, ISTA+, and other BMW diagnostic tools
///
/// Components:
/// - PsdzMappingService: PSDZ file indexing and mapping
/// - DeepEcuMappingEngine: ECU address registry and profiles
/// - DynamicResponseEngine: Real-time UDS response generation
/// - NcdCafdLoader: NCD and CAFD file parsing
/// - PsdzEcuFactory: Virtual ECU creation from PSDZ data
/// - LiveStreamingService: FA/SVT real-time streaming
/// - DeepSimulationEngine: Main integration engine
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library deep_simulation;

export 'psdz_mapping_service.dart';
export 'deep_ecu_mapping_engine.dart';
export 'dynamic_response_engine.dart';
export 'ncd_cafd_loader.dart';
export 'psdz_ecu_factory.dart';
export 'live_streaming_service.dart';
export 'deep_simulation_engine.dart';
