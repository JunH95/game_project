extends Node

## 씬 단위 오브젝트 풀. 투사체·적·XP 젬처럼 수백 개가 생겼다 사라지는 노드를 재사용한다.
## 매 프레임 instantiate 하면 노트북에서 스터터가 생긴다(design.md 15절).
##
## 사용 규약 — 풀에 들어갈 씬의 루트 스크립트는 아래 둘을 구현할 수 있다(선택):
##   `_pool_reset()` : 트리에 붙은 직후. 상태를 초기화하고 충돌·그룹을 되살린다.
##   `_pool_exit()`  : 반납 직전. 그룹에서 빼고 충돌을 끈다.
##
## 대기 중인 노드는 **트리 밖**에 둔다. 트리 안에 두면 처리를 꺼도 그룹 조회
## (`get_nodes_in_group`)에 잡혀 죽은 적이 무기 판정에 계속 걸린다.
## 트리에서 빼는 일은 물리 콜백 중에 할 수 없으므로 반납은 항상 지연 처리한다.

const META_SCENE: StringName = &"_pool_scene"
const META_RELEASING: StringName = &"_pool_releasing"

## { PackedScene: Array[Node] } — 반납되어 대기 중인 노드들(트리 밖).
var _free: Dictionary = {}


## 대기 노드는 트리 밖이라 자동 해제되지 않는다. 종료 시 직접 정리한다.
func _exit_tree() -> void:
	for bucket in _free.values():
		for node in bucket:
			if is_instance_valid(node):
				node.free()
	_free.clear()


## 미리 만들어 둔다. 관문 시작 전에 호출해 첫 스폰의 끊김을 없앤다.
func prewarm(scene: PackedScene, count: int) -> void:
	if scene == null:
		push_error("ObjectPool.prewarm: scene 이 null 이다.")
		return
	var bucket: Array = _bucket(scene)
	for i in count:
		var node := scene.instantiate()
		node.set_meta(META_SCENE, scene)
		bucket.append(node)


## 풀에서 꺼내 parent 에 붙인다. 남은 게 없으면 새로 만든다.
func acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		push_error("ObjectPool.acquire: scene 또는 parent 가 null 이다.")
		return null

	var bucket: Array = _bucket(scene)
	var node: Node = null
	while not bucket.is_empty():
		var candidate: Node = bucket.pop_back()
		if is_instance_valid(candidate):
			node = candidate
			break

	if node == null:
		node = scene.instantiate()
		node.set_meta(META_SCENE, scene)

	parent.add_child(node)
	# _pool_reset 은 트리에 붙은 뒤에 부른다 — 안에서 get_tree() 를 쓸 수 있어야 한다.
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node.has_method(&"_pool_reset"):
		node.call(&"_pool_reset")
	return node


## 다 쓴 노드를 돌려준다. 풀 소속이 아니면 그냥 해제한다.
## 트리에서 빼는 것은 지연 처리한다(물리 콜백 중 제거 금지).
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_meta(META_SCENE):
		node.queue_free()
		return
	# 같은 프레임에 두 번 반납되면(투사체 2발 동시 명중 등) 대기열에 중복으로 들어간다.
	if node.has_meta(META_RELEASING):
		return
	node.set_meta(META_RELEASING, true)

	if node.has_method(&"_pool_exit"):
		node.call(&"_pool_exit")
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	_finish_release.call_deferred(node)


func _finish_release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.remove_meta(META_RELEASING)
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	_bucket(node.get_meta(META_SCENE)).append(node)


func _bucket(scene: PackedScene) -> Array:
	if not _free.has(scene):
		_free[scene] = []
	return _free[scene]
