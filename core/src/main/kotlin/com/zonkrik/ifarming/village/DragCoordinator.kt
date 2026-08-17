package com.zonkrik.ifarming.village

/**
 * One shared flag between the camera's pan gesture (on `stage.root`) and every draggable
 * [Building]: Scene2D bubbles touch events to *all* ancestor listeners regardless of whether a
 * descendant's `touchDown` returned `true`, so without this, picking up a building and the root's
 * own pan detection would both react to the same touch stream -- double-moving things (the
 * building relocates from its own drag handling, and the camera pans underneath it at the same
 * time). The root pan listener checks [isDraggingBuilding] first and skips panning while a
 * building is armed/picked up.
 */
class DragCoordinator {
    var isDraggingBuilding: Boolean = false
}
