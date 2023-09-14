import macros, strutils, cglm, sokol/gfx as sgfx

type
  int32_t* {.importc, header: "stdint.h".} = int32

  TypeKind* = distinct int32

const
  idCacheSize = 32
  termDescCacheSize = 16

  EcsKeyW* = int32('w')
  EcsKeyS* = int32('s')
  EcsKeyA* = int32('a')
  EcsKeyD* = int32('d')

  PrimitiveType* = TypeKind(0)
  BitmaskType* = TypeKind(1)
  EnumType* = TypeKind(2)
  StructType* = TypeKind(3)
  ArrayType* = TypeKind(4)
  VectorType* = TypeKind(5)
  OpaqueType* = TypeKind(6)
  TypeKindLast* = OpaqueType

const
  MaxEventDesc* = 8
  MaxIdDesc* = 32
  MaxTermDesc* = 16

type
  FTime* = float32

  Flags8* = uint8
  Flags16* = uint16
  Flags32* = uint32
  Flags64* = uint64

  Size* = int32

when defined(debug):
  type
    Vec* = object
      data*: pointer
      count*: int32
      size*: int32
      elemSize*: Size
else:
  type
    Vec* = object
      data*: pointer
      count*: int32
      size*: int32

type
  Id* = uint64
  Entity* = Id
  Type* = object
    array*: ptr Id
    count*: int32

  World* = object
  Table* = object
  TableCacheHdr* = object
  Mixins* = object
  Query* = object
  QueryTableMatch* = object
  Rule* = object
  RuleOpCtx* = object
  IdRecord* = object

  TableRange* = object
    table*: ptr Table
    offset*: int32
    count*: int32

  Var* = object
    tableRange*: TableRange
    entity*: Entity

  RuleOpProfile* = object
    count*: array[2, int32] ##  0 = enter, 1 = redo

  RuleVar* = object
  RuleOp* = object

when defined(debug):
  type
    RuleIter* = object
      rule*: ptr Rule
      vars*: ptr Var
      ruleVars*: ptr RuleVar
      ops*: ptr RuleOp
      opCtx*: ptr RuleOpCtx
      written*: ptr uint64
      profile*: ptr RuleOpProfile
      redo*: bool
      op*: int16
      sp*: int16
else:
  type
    RuleIter* = object
      rule*: ptr Rule
      vars*: ptr Var
      ruleVars*: ptr RuleVar
      ops*: ptr RuleOp
      opCtx*: ptr RuleOpCtx
      written*: ptr uint64
      redo*: bool
      op*: int16
      sp*: int16

type
  Poly* {.incompleteStruct.} = object

  Header* = object
    magic*: int32
    `type`*: int32
    mixins*: ptr Mixins

  RunAction* = proc (it: ptr Iter) {.cdecl.}
  IterAction* = proc (it: ptr Iter) {.cdecl.}
  IterInitAction* = proc (world: ptr World; iterable: ptr Poly;
                               it: ptr Iter; filter: ptr Term) {.cdecl.}
  IterNextAction* = proc (it: ptr Iter): bool {.cdecl.}
  IterFiniAction* = proc (it: ptr Iter) {.cdecl.}
  OrderByAction* = proc (e1: Entity; ptr1: pointer; e2: Entity;
                              ptr2: pointer): cint {.cdecl.}
  SortTableAction* = proc (world: ptr World; table: ptr Table;
                                entities: ptr Entity; `ptr`: pointer;
                                size: int32; lo: int32; hi: int32;
                                orderBy: OrderByAction) {.cdecl.}
  GroupByAction* = proc (world: ptr World; table: ptr Table;
                              groupId: Id; ctx: pointer): uint64 {.cdecl.}
  GroupCreateAction* = proc (world: ptr World; groupId: uint64;
                                  groupByCtx: pointer): pointer {.cdecl.}
  GroupDeleteAction* = proc (world: ptr World; groupId: uint64;
                                  groupCtx: pointer;
                                      groupByCtx: pointer) {.cdecl.}
  ModuleAction* = proc (world: ptr World) {.cdecl.}
  FiniAction* = proc (world: ptr World; ctx: pointer) {.cdecl.}
  CtxFree* = proc (ctx: pointer) {.cdecl.}
  CompareAction* = proc (ptr1: pointer; ptr2: pointer): cint {.cdecl.}
  HashValueAction* = proc (`ptr`: pointer): uint64 {.cdecl.}
  Xtor* = proc (`ptr`: pointer; count: int32; typeInfo: ptr TypeInfo)
  Copy* = proc (dstPtr: pointer; srcPtr: pointer; count: int32;
                   typeInfo: ptr TypeInfo) {.cdecl.}
  Move* = proc (dstPtr: pointer; srcPtr: pointer; count: int32;
                   typeInfo: ptr TypeInfo) {.cdecl.}
  PolyDtor* = proc (poly: ptr Poly) {.cdecl.}
  Iterable* = object
    init*: IterInitAction

  IterKind* = distinct int32
  InoutKind* = distinct int32
    # EcsInOutDefault, EcsInOutNone, EcsInOut, EcsIn, EcsOut
  OperKind* = distinct int32
    # EcsAnd, EcsOr, EcsNot, EcsOptional, EcsAndFrom, EcsOrFrom, EcsNotFrom

  EntityDesc* = object
    canary: int32
    id*: Entity
    name*: cstring
    sep*: cstring
    rootSep*: cstring
    symbol*: cstring
    useLowId*: bool
    add*: array[MaxIdDesc, Id]
    addExpr*: cstring

  FilterDesc* = object
    canary: int32
    terms*: array[MaxTermDesc, Term]
    termsBuffer*: ptr Term
    termsBufferCount*: int32
    storage*: ptr Filter
    instanced*: bool
    flags*: Flags32
    filterExpr*: cstring
    entity*: Entity

  QueryDesc* = object
    canary: int32
    filter*: FilterDesc
    orderByComponent*: Entity
    orderBy*: OrderByAction
    sortTable*: SortTableAction
    groupById*: Id
    groupBy*: GroupByAction
    onGroupCreate*: GroupCreateAction
    onGroupDelete*: GroupDeleteAction
    groupByCtx*: pointer
    groupByCtxFree*: CtxFree
    parent*: ptr Query

  SystemDesc* = object
    canary: int32
    entity*: Entity
    query*: QueryDesc
    run*: RunAction
    callback*: IterAction
    ctx*: pointer
    bindingCtx*: pointer
    ctxFree*: CtxFree
    bindingCtxFree*: CtxFree
    interval*: FTime
    rate*: int32
    tickSource*: Entity
    multiThreaded*: bool
    noReadonly*: bool

  ComponentDesc* = object
    canary: int32
    entity*: Entity
    typeInfo*: TypeInfo

  TermId* = object
    id*: Entity
    name*: cstring
    trav*: Entity
    flags*: Flags32

  Sparse* = object
    dense*: Vec
    pages*: Vec
    size*: Size
    count*: int32
    maxId*: uint64
    allocator*: ptr Allocator
    pageAllocator*: ptr BlockAllocator

  Term* = object
    id*: Id
    src*: TermId
    first*: TermId
    second*: TermId
    inout*: InoutKind
    oper*: OperKind
    idFlags*: Id
    name*: cstring
    fieldIndex*: int32
    idr*: ptr IdRecord
    flags*: Flags16
    move*: bool

  Filter* = object
    hdr*: Header
    terms*: ptr Term
    termCount*: int32
    fieldCount*: int32
    owned*: bool
    termsOwned*: bool
    flags*: Flags32
    variableNames*: array[1, cstring]
    sizes*: ptr int32
    entity*: Entity
    iterable*: Iterable
    dtor*: PolyDtor
    world*: ptr World

  Observer* = object
    hdr*: Header
    filter*: Filter
    events*: array[MaxEventDesc, Entity]
    eventCount*: int32
    callback*: IterAction
    run*: RunAction
    ctx*: pointer
    bindingCtx*: pointer
    ctxFree*: CtxFree
    bindingCtxFree*: CtxFree
    observable*: ptr Observable
    lastEventId*: ptr int32
    lastEventIdStorage*: int32
    registerId*: Id
    termIndex*: int32
    isMonitor*: bool
    isMulti*: bool
    dtor*: PolyDtor

  TypeHooks* = object
    ctor*: Xtor
    dtor*: Xtor
    copy*: Copy
    move*: Move
    copyCtor*: Copy
    moveCtor*: Move
    ctorMoveDtor*: Move
    moveDtor*: Move
    onAdd*: IterAction
    onSet*: IterAction
    onRemove*: IterAction
    ctx*: pointer
    bindingCtx*: pointer
    ctxFree*: CtxFree
    bindingCtxFree*: CtxFree

  TypeInfo* = object
    size*: Size
    alignment*: Size
    hooks*: TypeHooks
    component*: Entity
    name*: cstring

  EventIdRecord* = object

  EventRecord* = object
    anyRecord*: ptr EventIdRecord
    wildcardRecord*: ptr EventIdRecord
    wildcardPairRecord*: ptr EventIdRecord
    eventIds*: Map
    event*: Entity

  Observable* = object
    onAdd*: EventRecord
    onRemove*: EventRecord
    onSet*: EventRecord
    unSet*: EventRecord
    onWildcard*: EventRecord
    events*: Sparse

  Record* = object
    idr*: ptr IdRecord
    table*: ptr Table
    row*: uint32
    dense*: int32

  Ref* = object
    entity*: Entity
    id*: Entity
    tr*: ptr TableRecord
    record*: ptr Record

  PageIter* = object
    offset*: int32
    limit*: int32
    remaining*: int32

  WorkerIter* = object
    index*: int32
    count*: int32

  TableCacheIter* = object
    cur*, next*: ptr TableCacheHdr
    nextList*: ptr TableCacheHdr

  TermIter* = object
    term*: Term
    selfIndex*: ptr IdRecord
    setIndex*: ptr IdRecord
    cur*: ptr IdRecord
    it*: TableCacheIter
    index*: int32
    observedTableCount*: int32
    table*: ptr Table
    curMatch*: int32
    matchCount*: int32
    lastColumn*: int32
    emptyTables*: bool ##  Storage
    id*: Id
    column*: int32
    subject*: Entity
    size*: Size
    `ptr`*: pointer

  FilterIter* = object
    filter*: ptr Filter
    kind*: IterKind
    termIter*: TermIter
    matchesLeft*: int32
    pivotTerm*: int32

  QueryIter* = object
    query*: ptr Query
    node*: ptr QueryTableMatch
    prev*: ptr QueryTableMatch
    last*: ptr QueryTableMatch
    sparseSmallest*: int32
    sparseFirst*: int32
    bitsetFirst*: int32
    skipCount*: int32

  SnapshotIter* = object
    filter*: Filter
    tables*: Vec ##  TableLeaf
    index*: int32

  IterData* {.union.} = object
    term*: TermIter
    fliter*: FilterIter
    query*: QueryIter
    rule*: RuleIter
    snapshot*: SnapshotIter
    page*: PageIter
    worker*: WorkerIter

  StackPage* = object

  StackCursor* = object
    cur*: StackPage
    sp*: int16

  IterCache* = object
    stackCursor*: StackCursor
    used*: Flags8
    allocated*: Flags8

  IterPrivate* = object
    iter*: IterData
    entityIter*: pointer
    cache*: IterCache

  Iter* = object
    world*: ptr World
    realWorld*: ptr World
    entities*: ptr Entity
    ptrs*: ptr pointer
    sizes*: ptr Size
    table*: ptr Table
    otherTable*: ptr Table
    ids*: ptr Id
    variables*: ptr Var
    columns*: ptr int32
    sources*: ptr Entity
    matchIndices*: ptr int32
    references*: ptr Ref
    constrainedVars*: Flags64
    groupId*: uint64
    fieldCount*: int32
    system*: Entity
    event*: Entity
    eventId*: Id
    terms*: ptr Term
    tableCount*: int32
    termIndex*: int32
    variableCount*: int32
    variableNames*: cstringArray
    param*: pointer
    ctx*: pointer
    bindingCtx*: pointer
    deltaTime*: Ftime
    deltaSystemTime*: Ftime
    frameOffset*: int32
    offset*: int32
    count*: int32
    instanceCount*: int32
    flags*: Flags32
    interruptedBy*: Entity
    priv*: IterPrivate
    next*: IterNextAction
    callback*: IterAction
    fini*: IterFiniAction
    chainIt*: ptr Iter

  TableRecord* = object
    hdr*: TableCacheHdr
    column*: int32
    count*: int32

  IdRecordElem* = object
    prev*: ptr IdRecord
    next*: ptr IdRecord

  ReachableElem* = object
    tr*: ptr TableRecord
    record*: ptr Record
    src*: Entity
    id*: Id
    table*: ptr Table

  ReachableCache* = object
    generation*: int32
    current*: int32
    ids*: Vec

  MapData* = uint64
  MapKey* = MapData
  MapVal* = MapData
  BucketEntry* = object
    key*: MapKey
    value*: MapVal
    next*: ptr BucketEntry

  Bucket* = object
    first*: ptr BucketEntry

  Map* = object
    bucketShift*: uint8
    sharedAllocator*: bool
    buckets*: ptr Bucket
    bucketCount*: int32
    count*: int32
    entryAllocator*: ptr BlockAllocator
    allocator*: ptr Allocator

  MapIter* = object
    map*: ptr Map
    bucket*: ptr Bucket
    entry*: ptr BucketEntry
    res*: ptr MapData

  MapParams* = object
    allocator*: ptr Allocator
    entryAllocator*: BlockAllocator

  BlockAllocatorBlock* = object
    memory*: pointer
    next*: ptr BlockAllocatorBlock

  BlockAllocatorChunkHeader* = object
    next*: ptr BlockAllocatorChunkHeader

  BlockAllocator* = object
    head*: ptr BlockAllocatorChunkHeader
    blockHead*: ptr BlockAllocatorBlock
    blockTail*: ptr BlockAllocatorBlock
    chunkSize*: int32
    dataSize*: int32
    chunksPerBlock*: int32
    blockSize*: int32
    allocCount*: int32

  Allocator* = object
    chunks*: BlockAllocator
    sizes*: Sparse

  InitAppAction* = proc(world: ptr World): int32 {.cdecl.}

  AppDesc* = object
    targetFps*: float32
    deltaTime*: float32
    threads*: int32
    frames*: int32
    enableRest*: bool
    enableMonitor*: bool
    init*: InitAppAction
    ctx*: pointer

  Rgb* = object
    r*: float32
    g*: float32
    b*: float32

  EcsCanvas* = object
    title*: cstring
    width*: int32
    height*: int32
    camera*: Entity
    directionalLight*: Entity
    backgroundColor*: EcsRgb
    ambientLight*: EcsRgb
    fogDensity*: float32

  EcsCamera* = object
    position: array[3, float32]
    lookAt*: array[3, float32]
    up*: array[3, float32]
    fov*: float32
    near*: float32
    far*: float32
    ortho*: bool

  EcsDirectionalLight* = object
    position*: array[3, float32]
    direction*: array[3, float32]
    color*: array[3, float32]
    intensity*: float32

  EcsPosition3* = object
    x*: float32
    y*: float32
    z*: float32

  EcsRotation3* = object
    x*: float32
    y*: float32
    z*: float32

  EcsRgb* = object
    r*: float32
    g*: float32
    b*: float32

  EcsBox* = object
    width*: float32
    height*: float32
    depth*: float32

  EcsMeshVertex* = object
    position*: array[3, float32]
    normal*: uint32
    jointIndices*: uint32
    jointWeights*: uint32

  EcsMesh* = object
    unused: char

  EcsKeyState* = object
    pressed*: bool
    state*: bool
    current*: bool

  EcsMouseCoord* = object
    x*: float32
    y*: float32

  EcsMouseState* = object
    left*: EcsKeyState
    right*: EcsKeyState
    wnd*: EcsMouseCoord
    rel*: EcsMouseCoord
    view*: EcsMouseCoord
    scroll*: EcsMouseCoord

  EcsInput* = object
    keys*: array[128, EcsKeyState]
    mouse*: EcsMouseState

  SokolMaterial* = object
    specularPower*: float32
    shininess*: float32
    emissive*: float32

  SokolGeometryAction* = proc(transforms: ptr Mat4; data: pointer; count: int32;
      self: bool) {.cdecl.}

  SokolGeometryPage* = object
    colors*: ptr Rgb
    transforms*: ptr Mat4
    materials*: ptr SokolMaterial
    count*: int32
    next*: ptr SokolGeometryPage

  SokolGeometryGroup* = object
    firstPage*: ptr SokolGeometryPage
    lastPage*: ptr SokolGeometryPage
    firstNoData*: ptr SokolGeometryPage
    prev*, next*: ptr SokolGeometryGroup
    buffer*: ptr SokolGeometryBuffer
    drawDistance*: Ref
    count*: int32
    matchCount*: int32
    visible*: bool
    id*: uint64

  SokolGeometryBuffer* = object
    id*: Entity
    cellCoord*: Ref
    groups*: ptr SokolGeometryGroup
    prev*, next*: ptr SokolGeometryBuffer
    changed*: bool

  SokolGeometryBuffers* = object
    first*: ptr SokolGeometryBuffer
    index*: Map
    colorsData*: Vec
    transformsData*: Vec
    materialsData*: Vec
    colors*: sgfx.Buffer
    transforms*: sgfx.Buffer
    materials*: sgfx.Buffer
    instanceCount*: int32
    allocator*: Allocator

  SokolGeometry* = object
    vertices*: sgfx.Buffer
    normals*: sgfx.Buffer
    indices*: sgfx.Buffer

    indexCount*: int32

    solid*: ptr SokolGeometryBuffers
    emissive*: ptr SokolGeometryBuffers

    populate*: SokolGeometryAction

    groupIds*: Vec

  SokolGeometryQuery* = object
    component*: Entity
    parentQuery*: ptr Query
    solid*: ptr Query
    emissive*: ptr Query

  SokolSkin* = object
    jointUv*: array[2, float32]


var
  Phase* {.importc: "EcsPhase".}: Entity
  Geometry* {.importc: "EcsGeometry".}: Entity
  SokolMeshGeometry* {.importc: "SokolMeshGeometry".}: Entity
  FLECS_EEcsGeometry* {.importc: "FLECS_EEcsGeometry".}: Entity
  FLECS_EEcsBox* {.importc: "FLECS_EEcsBox".}: Entity
  FLECS_EEcsMesh* {.importc: "FLECS_EEcsMesh".}: Entity
  FLECS_EEcsCanvas* {.importc: "FLECS_EEcsCanvas".}: Entity
  FLECS_EEcsCamera* {.importc: "FLECS_EEcsCamera".}: Entity
  FLECS_EEcsCameraController* {.importc: "FLECS_EEcsCameraController".}: Entity
  FLECS_EEcsDirectionalLight* {.importc: "FLECS_EEcsDirectionalLight".}: Entity
  FLECS_EEcsPosition3* {.importc: "FLECS_EEcsPosition3".}: Entity
  FLECS_EEcsRotation3* {.importc: "FLECS_EEcsRotation3".}: Entity
  FLECS_EEcsRgb* {.importc: "FLECS_EEcsRgb".}: Entity
  FLECS_EEcsInput* {.importc: "FLECS_EEcsInput".}: Entity
  FLECS_ESokolRender* {.importc: "FLECS_ESokolRender".}: Entity
  FLECS_ESokolCommit* {.importc: "FLECS_ESokolCommit".}: Entity
  FLECS_ESokolGeometry* {.importc: "FLECS_ESokolGeometry".}: Entity
  FLECS_ESokolMeshGeometry* {.importc: "FLECS_ESokolMeshGeometry".}: Entity
  FLECS_ESokolGeometryQuery* {.importc: "FLECS_ESokolGeometryQuery".}: Entity
  FLECS_ESokolPopulateGeometry* {.importc: "FLECS_ESokolPopulateGeometry".}: Entity
  FLECS_ESokolInitMaterials* {.importc: "FLECS_ESokolInitMaterials".}: Entity
  FLECS_ESokolRegisterMaterial* {.importc: "FLECS_ESokolRegisterMaterial".}: Entity
  FLECS_ESokolSkin* {.importc: "FLECS_ESokolSkin".}: Entity

  FLECS_EInitMeshRenderer* {.importc: "FLECS_EInitMeshRenderer".}: Entity

proc initWorld*(): ptr World {.importc: "ecs_init", cdecl.}
proc setLogLevel*(level: int32): int32 {.importc: "ecs_log_set_level", cdecl, discardable.}
proc setTargetFps*(world: ptr World; fps: float32) {.importc: "ecs_set_target_fps", cdecl.}
proc shouldQuit*(world: ptr World): bool {.importc: "ecs_should_quit", cdecl.}
proc runApp*(world: ptr World; desc: ptr AppDesc): int32 {.importc: "ecs_app_run", cdecl.}
proc runAppFrame*(world: ptr World; dessc: ptr AppDesc): int32 {.importc: "ecs_app_run_frame",
    cdecl, discardable.}
proc initComponent*(world: ptr World; desc: ptr ComponentDesc): Entity {.importc: "ecs_component_init", cdecl.}
proc metaFromDesc*(world: ptr World; component: Entity; kind: TypeKind;
    desc: cstring): int32 {.importc: "ecs_meta_from_desc", cdecl, discardable.}
proc newId*(world: ptr World): Entity {.importc: "ecs_new_id", cdecl.}
proc newWId*(world: ptr World; id: Id): Entity {.importc: "ecs_new_w_id", cdecl.}
proc initEntity*(world: ptr World; desc: ptr EntityDesc): Entity {.importc: "ecs_entity_init", cdecl.}
proc setEntityName*(world: ptr World; entity: Entity;
    name: cstring): Entity {.importc: "ecs_set_name", cdecl.}
proc lookup*(world: ptr World; name: cstring): Entity {.importc: "ecs_lookup", cdecl.}
proc initSystem*(world: ptr World; desc: ptr SystemDesc): Entity {.importc: "ecs_system_init", cdecl.}
# proc newId*(world: ptr World): Entity {.importc: "ecs_new_id", cdecl.}
proc setId*(world: ptr World; entity: Entity; id: Id; size: uint;
    p: pointer): Entity {.importc: "ecs_set_id", cdecl, discardable.}
proc getId*(world: ptr World; entity: Entity;
    id: Id): pointer {.importc: "ecs_get_id", cdecl.}
proc getMutId*(world: ptr World; entity: Entity;
    id: Id): pointer {.importc: "ecs_get_mut_id", cdecl.}
proc addId*(world: ptr World; entity: Entity; id: Id) {.importc: "ecs_add_id", cdecl.}
proc hasId*(world: ptr World; entity: Entity;
    id: Id): bool {.importc: "ecs_has_id", cdecl.}
proc fieldWSize*(it: ptr Iter; size: uint;
    idx: int32): pointer {.importc: "ecs_field_w_size", cdecl.}
proc tableStr*(world: ptr World; table: ptr Table): cstring {.importc: "ecs_table_str", cdecl.}
proc progress*(world: ptr World; deltaTime: float32): bool {.importc: "ecs_progress",
    cdecl, discardable.}
proc importC*(world: ptr World; module: ModuleAction;
    moduleName: cstring): Entity {.importc: "ecs_import_c", cdecl, discardable.}
proc destroyWorld*(world: ptr World): int32 {.importc: "ecs_fini", cdecl, discardable.}
proc fullPath*(world: ptr World; parent, child: Entity; sep: cstring;
    prefix: cstring): cstring {.importc: "ecs_get_path_w_sep", cdecl.}
proc getType*(world: ptr World; entity: Entity): ptr Type {.importc: "ecs_get_type", cdecl.}
proc typeStr*(world: ptr World; ecsType: ptr Type): cstring {.importc: "ecs_type_str", cdecl.}
proc entityStr*(world: ptr World; entity: Entity): cstring {.importc: "ecs_entity_str", cdecl.}
proc run*(world: ptr World; system: Entity; deltaTime: float32;
    param: pointer): Entity {.importc: "ecs_run", cdecl, discardable.}
proc modifiedId*(world: ptr World; entity: Entity;
    id: Id) {.importc: "ecs_modified_id", cdecl.}
proc initModule*(world: ptr World; name: cstring;
    desc: ptr ComponentDesc): Entity {.importc: "ecs_module_init", cdecl.}
proc setNamePrefix*(world: ptr World; prefix: cstring): cstring {.importc: "ecs_set_name_prefix", cdecl, discardable.}

# proc newSQuery*(world: ptr World; filter: Id; center: Vec3; size: float32): ptr SQuery {.importc: "ecs_squery_new", cdecl.}
# proc freeSQuery*(sq: ptr SQuery): ptr SQuery {.importc: "ecs_squery_free", cdecl.}

proc FlecsComponentsTransformImport*(world: ptr World) {.importc: "FlecsComponentsTransformImport", cdecl.}
proc FlecsComponentsGraphicsImport*(world: ptr World) {.importc: "FlecsComponentsGraphicsImport", cdecl.}
proc FlecsComponentsGeometryImport*(world: ptr World) {.importc: "FlecsComponentsGeometryImport", cdecl.}
proc FlecsComponentsGuiImport*(world: ptr World) {.importc: "FlecsComponentsGuiImport", cdecl.}
proc FlecsComponentsPhysicsImport*(world: ptr World) {.importc: "FlecsComponentsPhysicsImport", cdecl.}
proc FlecsComponentsInputImport*(world: ptr World) {.importc: "FlecsComponentsInputImport", cdecl.}
proc FlecsSystemsTransformImport*(world: ptr World) {.importc: "FlecsSystemsTransformImport", cdecl.}
proc FlecsSystemsPhysicsImport*(world: ptr World) {.importc: "FlecsSystemsPhysicsImport", cdecl.}
proc FlecsMonitorImport*(world: ptr World) {.importc: "FlecsMonitorImport", cdecl.}
proc FlecsGameImport*(world: ptr World) {.importc: "FlecsGameImport", cdecl.}
proc FlecsSystemsSokolImport*(world: ptr World) {.importc: "FlecsSystemsSokolImport", cdecl.}

proc MeshSystemsImport*(world: ptr World) {.importc: "MeshSystemsImport", cdecl.}


const
  HiComponentId* = 256'u64

  Pair = Id(1'u64 shl 63)

  With* = HiComponentId + 25
  DependsOn* = HiComponentId + 29

  OnStart* = HiComponentId + 64
  OnLoad* = HiComponentId + 66
  PreUpdate* = HiComponentId + 68
  OnUpdate* = HiComponentId + 69

  iokDefault* = InOutKind(0)
  iokNone* = InOutKind(0)
  iokInOut* = InOutKind(0)
  iokIn* = InOutKind(0)
  iokOut* = InOutKind(0)

# macro flecsId*(T: untyped): untyped =
#   let typeName = $`T`
#   result = quote do:
#     ident("FLECS_EEcs" & typeName)

macro defineEntity*(world, id: untyped; args: varargs[untyped]): untyped =
  let
    entityName = $`id`
    entityId = ident("FLECS_E" & entityName)

  var addExpr = ""
  for i, arg in args:
    addExpr = if i > 0: join([addExpr, $arg], ", ") else: $arg

  result = quote do:
    var desc: EntityDesc

    desc.id = `id`
    desc.addExpr = cstring(`addExpr`)
    `id` = initEntity(`world`, addr(desc))
    `entityId` = `id`
    assert(`id` != 0)

# template defineEntity*(world, id: untyped; args: varargs[untyped]): untyped =
#   var eDesc: EntityDesc
#   eDesc.id = id
#   eDesc.name = astToStr(id)
#   eDesc.addExpr =
#   `id` = initEntity(world, addr(eDesc))
#   `FLECS_E id` = `id`

template ecsId*(T: untyped): untyped =
  `FLECS_E T`

template declare*(id: untyped): untyped =
  var
    `id`* {.inject, exportc.}: Entity
    `FLECS_E id`* {.inject, exportc.}: Entity

template declareComponent*(id: untyped): untyped =
  var `FLECS_E id`* {.inject.}: Entity

template declareSystem*(id: untyped): untyped =
  var `FLECS_E id`* {.inject, exportc.}: Entity

template defineTag*(world, id): untyped =
  defineEntity(world, id, 0)

template load*(world: ptr World; id: untyped): untyped =
  importC(world, `id Import`, astToStr(id))

template entityComb(lo, hi: untyped): untyped =
  uint64(hi) shl 32 + uint32(lo)

template pair*(pre, obj: untyped): untyped =
  Pair or entityComb(obj, pre)

template addPair*(world, subject, first, second: untyped): untyped =
  addId(world, subject, pair(first, second))

macro component(world, id: untyped): untyped =
  let
    componentName = $`id`
    componentId = ident("FLECS_E" & componentName)

  result = quote do:
    var
      `componentId`: Entity
      desc: ComponentDesc
      eDesc: EntityDesc

    eDesc.id = `componentId`
    eDesc.useLowId = true
    eDesc.name = `componentName`
    eDesc.symbol = `componentName`
    desc.entity = initEntity(`world`, addr(eDesc))
    desc.typeInfo.size = int32(sizeof(`id`))
    desc.typeInfo.alignment = int32(alignof(`id`))
    `componentId` = initComponent(`world`, addr(desc))
    assert(`componentId` != 0)

  echo repr result

macro join(prefix, infix, suffix: untyped): untyped =
  newIdentNode($`prefix` & $`infix` & $`suffix`)

template metaComponent*(world, name: untyped): untyped =
  component(world, name)
  metaFromDesc(world, `FLECS_E name`, join("FLECS_", name, "_kind"), join(
      "FLECS_", name, "_desc"))

template callInnerMetaImpl(base, impl, name, desc: untyped) =
  `base impl`(name, desc)

template callMetaImpl*(base, impl, name, desc: untyped): untyped =
  callInnerMetaImpl(base, impl, name, desc)

macro struct*(name, body: untyped): untyped =
  let
    typeName = newIdentNode($`name`)
    entityName = newIdentNode("FLECS_E" & $`name`)
    descIdent = newIdentNode("FLECS_" & $`name` & "_desc")
    kindIdent = newIdentNode("FLECS_" & $`name` & "_kind")

  var
    i = 0
    desc = "{"
    recList = nnkRecList.newTree()
  for child in body.children:
    if child.kind == nnkCall:
      let
        memberName = $child[0]
        memberType = $child[1][0]

      recList.add(
        nnkIdentDefs.newTree(
          newIdentNode(memberName),
          newIdentNode(memberType),
          newEmptyNode()
        )
      )

      desc &= memberType & " " & memberName & ";"
      if i < body.len() - 1:
        desc &= " "
      else:
        desc &= "}"

      inc(i)

  result = newNimNode(nnkStmtList)
  result.add quote do:
    var
      `entityName` {.inject.}: Entity
      `descIdent`: cstring = `desc`
      `kindIdent`: TypeKind = StructType

  result.add(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPostfix.newTree(
          newIdentNode("*"),
          typeName,
        ),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          recList
        )
      )
    )
  )

macro str*(def: untyped): untyped =
  # callMetaImpl(struct, MetaImpl, name, args)
  discard
  # structType(name, body)

macro defineSystem*(world, id, phase: untyped; args: varargs[typed]): untyped =
  let
    systemName = $`id`
    systemId = ident("FLECS_E" & systemName)

  var filterExpr = ""
  for i, arg in args:
    filterExpr = if i > 0: join([filterExpr, $arg], ", ") else: $arg

  result = quote do:
    var
      desc: SystemDesc
      eDesc: EntityDesc

    eDesc.id = `systemId`
    eDesc.name = `systemName`
    eDesc.add[0] = if bool(`phase`): pair(DependsOn, `phase`) else: 0
    eDesc.add[1] = `phase`
    desc.entity = initEntity(`world`, addr(eDesc))
    desc.query.filter.filterExpr = `filterExpr`
    desc.callback = `id`
    `systemId` = initSystem(`world`, addr(desc))

  echo repr result

template entity*(world, id: untyped; args: varargs[untyped]): untyped =
  var
    `FLECS_E id` {.inject.}: Entity
    `id` {.inject.}: Entity
  defineEntity(world, `id`, args)

template tag*(world, id: untyped): untyped =
  entity(world, id, 0)

template newEntity*(world, n: untyped): untyped =
  var desc = EntityDesc(
    name: $n
  )
  initEntity(world, addr(desc))

# macro set*(world, entity, component, val: untyped): untyped =
#   let
#     componentName = $`component`
#     componentId = ident("FLECS_E" & componentName)

#   result = quote do:
#     var vVal = `val`
#     setId(`world`, `entity`, `componentId`, uint(sizeof(`component`)), cast[pointer](addr(vVal)))

template has*(world, entity, T: untyped): untyped =
  hasId(world, entity, ecsId(T))

template set*(world, entity, id, name, val: untyped): untyped =
  var vVal = val
  setId(world, entity, id, uint(sizeof(name)), addr(vVal))

template add*(world, entity, T: untyped): untyped =
  addId(world, entity, ecsId(T))

template addPair(world, subject, first, second: untyped): untyped =
  addId(world, subject, pair(first, second))

macro get(world, entity, T: untyped): untyped =
  let
    id = ident("FLECS_E" & $`T`)
  result = quote do:
    cast[ptr `T`](getId(`world`, `entity`, `id`))

macro field*(it, T, idx: untyped): untyped =
  result = quote do:
    cast[ptr `T`](fieldWSize(`it`, uint(sizeof(`T`)), `idx`))

# template osFree(p: untyped) =
#   osApi.free(p)

template getMut*(world, entity, T: untyped): untyped =
  cast[ptr T](getMutId(world, entity, `FLECS_E T`))

template setSingleton*(world, comp: untyped; args: varargs[untyped]): untyped =
  set(world, `FLECS_E comp`, `FLECS_E comp`, comp, args)

template modified*(world, entity, comp: untyped): untyped =
  modifiedId(world, entity, `FLECS_E comp`)

template defineModule(world, id: untyped): untyped =
  var desc: ComponentDesc
  desc.entity = `FLECS_E id`
  `FLECS_E id` = initModule(world, astToStr(id), addr(desc))

template module*(world, id: untyped): untyped =
  var `FLECS_E id` {.inject.}: Entity = 0
  defineModule(world, id)

{.passC: "-IC:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\flecs.c".}

{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-cglm\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-cglm\\src\\main.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-transform\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-transform\\src\\transform.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-graphics\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-graphics\\src\\graphics.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-geometry\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-geometry\\src\\geometry.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-physics\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-physics\\src\\physics.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-gui\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-gui\\src\\main.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-input\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-components-input\\src\\main.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-transform\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-transform\\src\\main.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-physics\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-physics\\src\\main.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-physics\\src\\octree.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-physics\\src\\spatial_query.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\include".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\modules\\renderer".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\main.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\resources.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\scene.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\effect.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\shader_loader.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\depth.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\atmosphere.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\shadow.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\screen.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\fx\\fx.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\fx\\fog.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\fx\\hdr.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\fx\\ssao.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\modules\\materials\\materials.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\modules\\renderer\\renderer.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-systems-sokol\\src\\modules\\geometry\\geometry.c".}
{.passC: "-I C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-game\\include".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-game\\src\\main.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-game\\src\\world_cells.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-game\\src\\camera_controller.c".}
{.compile: "C:\\Users\\Zach\\dev\\arkana\\thirdparty\\flecs\\hub\\flecs-game\\src\\light_controller.c".}


when isMainModule:
  import strformat

  type
    Position = object
      x, y: float64

    Velocity = object
      x, y: float64

  proc mv(it: ptr Iter) {.cdecl.} =
    let
      p = cast[ptr UncheckedArray[Position]](field(it, Position, 1))
      v = cast[ptr UncheckedArray[Velocity]](field(it, Velocity, 2))
      typeStr = tableStr(it.world, it.table)

    echo &"Move entities with [{typeStr}]"
    # osFree(typeStr)

    for i in 0 ..< it.count:
      p[i].x += v[i].x
      p[i].y += v[i].y

  let w = initWorld()
  component(w, Position)
  component(w, Velocity)

  system(w, mv, OnUpdate, Position, Velocity)

  tag(w, Eats)
  tag(w, Apples)
  tag(w, Pears)

  let bob = newEntity(w, "Bob")
  set(w, bob, FLECS_EPosition, Position, Position(x: 0, y: 0))
  set(w, bob, FLECS_EVelocity, Velocity, Velocity(x: 1, y: 2))
  addPair(w, bob, Eats, Apples)

  progress(w, 0)
  progress(w, 0)

  let p = get(w, bob, Position)
  echo &"Bob's position is: {{{p.x}, {p.y}}}"

  destroyWorld(w)

  # Output
  #  Move entities with [Position, Velocity, (Identifier,Name), (Eats,Apples)]
  #  Move entities with [Position, Velocity, (Identifier,Name), (Eats,Apples)]
  #  Bob's position is {2.0, 4.0}
