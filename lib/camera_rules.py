"""Camera modification rules as pure data.

Each axis (height, centered, steadycam, combat) defines a set of
element-level attribute changes. These are composed together by
build_modifications() into a single ModificationSet.
"""

from dataclasses import dataclass, field


@dataclass
class ModificationSet:
    element_mods: dict = field(default_factory=dict)
    fov_value: int = 0
    distance_multiplier: float = 1.0


# Vanilla base FOV (from Player_Basic_Default).  Used as the normalisation
# target for steadycam and as the engine fallback for entries that omit Fov.
BASE_FOV = 40


# Section lists

# Core sections — have InDoorUpOffset in vanilla, safe to modify both offsets
_BASIC_SECTIONS = [
    'Player_Basic_Default',
    'Player_Basic_Default_Aim_Zoom',
    'Player_Basic_Default_Walk',
    'Player_Basic_Default_Run',
    'Player_Basic_Default_Runfast',
    'Player_Basic_RopePull',
    'Player_Basic_RopeSwing',
    'Player_Rest',
]

# Extended sections — only UpOffset (no InDoorUpOffset in vanilla)
_BASIC_EXTENDED_SECTIONS = [
    'Player_Basic_ZoomLookAt',
    'Player_Basic_Zoom',
    'Player_Basic_PointClimb',
    'Player_Basic_CharacterClimb',
    'Player_Basic_PointClimb_Follow',
    'Player_Basic_Climb',
    'Player_Basic_Wide',
    'Player_Basic_Wide_Action',
    'Player_Basic_NoZoom',
    'Player_Basic_AirBalloon',
    'Player_Basic_Tank',
    'Player_Basic_RailGun',
    'Player_Basic_Cockpit',
    'Player_Basic_GantryCrane',
    'Player_Basic_GantryCrane_Big',
    'Player_Basic_GantryCrane_Small',
    'Player_Basic_FreeFall_Start',
    'Player_Basic_FreeFall',
    'Player_Basic_FreeFall_Lv2',
    'Player_Basic_FreeFall_Aim',
    'Player_Basic_Gliding',
    'Player_Basic_Gliding_Fast',
    'Player_Basic_Gliding_Zoom',
    'Player_Basic_Gliding_Fall',
    'Player_Basic_SuperJump',
    'Player_Basic_Teleport',
    'Player_Basic_Wagon',
    'Player_Contemplation',
]

_ALL_BASIC_SECTIONS = _BASIC_SECTIONS + _BASIC_EXTENDED_SECTIONS

_WEAPON_SECTIONS = [
    'Player_Weapon_Default',
    'Player_Weapon_Default_Walk',
    'Player_Weapon_Default_Run',
    'Player_Weapon_Default_RunFast',
    'Player_Weapon_Default_RunFast_Follow',
    'Player_Weapon_Rush',
    'Player_Weapon_Guard',
]

_RIDE_SECTIONS = [
    'Player_Ride_Horse',
    'Player_Ride_Horse_Run',
    'Player_Ride_Horse_Fast_Run',
    'Player_Ride_Horse_Dash',
    'Player_Ride_Horse_Dash_Att',
    'Player_Ride_Horse_Att_Thrust',
    'Player_Ride_Horse_Att_R',
    'Player_Ride_Horse_Att_L',
    'Player_Ride_Elephant',
    'Player_Ride_Wyvern',
    'Player_Ride_Broom',
    'Player_Ride_Canoe',
    'Player_Ride_Warmachine',
    'Player_Ride_Warmachine_Aim',
    'Player_Ride_Warmachine_Dash',
    'Player_Ride_Cannon_Wait',
    'Player_Ride_Cannon_Aim',
    'Player_Ride_Cannon_Aim_Shot',
    'Player_Ride_Giant_Cannon_Aim',
    'Player_Ride_Giant_Cannon_Aim_Shot_Ready',
    'Player_Ride_Giant_Cannon_Aim_Shot',
    'Player_Ride_Catapult_Wait',
    'Player_Ride_Catapult_Aim',
    'Player_Ride_Aim_Zoom',
    'Player_Ride_Aim_LockOn',
    'Player_Ride_Crossbow',
    'Player_Ride_Musket_Aim_Zoom',
    'Player_Ride_Musket_Aim_Front',
]


# Utilities

def _merge(base, overlay):
    """Deep-merge overlay into base (overlay wins on conflict)."""
    for key, attrs in overlay.items():
        if key in base:
            base[key].update(attrs)
        else:
            base[key] = dict(attrs)


# Height

def _build_height_mods(height):
    """Build UpOffset/InDoorUpOffset modifications for the given height."""
    offsets = {
        'slight': {'UpOffset': '0.15', 'InDoorUpOffset': '0.1'},
        'medium': {'UpOffset': '0.0',  'InDoorUpOffset': '-0.1'},
        'vlow':   {'UpOffset': '-0.2', 'InDoorUpOffset': '-0.3'},
    }
    if height not in offsets:
        return {}

    vals = offsets[height]
    mods = {}
    # Core basic + weapon: both UpOffset and InDoorUpOffset
    for section in _BASIC_SECTIONS + _WEAPON_SECTIONS:
        for level in (2, 3, 4):
            key = f'{section}/ZoomLevel[{level}]'
            mods[key] = {
                'UpOffset': ('SET', vals['UpOffset']),
                'InDoorUpOffset': ('SET', vals['InDoorUpOffset']),
            }
    # Extended basic: UpOffset only (no InDoorUpOffset in vanilla)
    for section in _BASIC_EXTENDED_SECTIONS:
        for level in (2, 3, 4):
            key = f'{section}/ZoomLevel[{level}]'
            mods[key] = {
                'UpOffset': ('SET', vals['UpOffset']),
            }
    # Ride: UpOffset only
    for section in _RIDE_SECTIONS:
        for level in (2, 3, 4, 5):
            key = f'{section}/ZoomLevel[{level}]'
            mods[key] = {
                'UpOffset': ('SET', vals['UpOffset']),
            }
    return mods


# Centered

def _build_centered_mods():
    mods = {}
    for section in _ALL_BASIC_SECTIONS + _WEAPON_SECTIONS + _RIDE_SECTIONS:
        for level in (2, 3, 4, 5):
            key = f'{section}/ZoomLevel[{level}]'
            mods.setdefault(key, {})['RightOffset'] = ('SET', '0.0')
    return mods


# Steadycam

_STEADYCAM_NORMALIZE_SECTIONS = [
    'Player_Basic_Default_Walk',
    'Player_Basic_Default_Run',
    'Player_Basic_Default_Runfast',
    'Player_Weapon_Default_Walk',
    'Player_Weapon_Default_Run',
    'Player_Weapon_Default_RunFast',
    'Player_Weapon_Default_RunFast_Follow',
]

_STEADYCAM_IDLE_DISTANCES = {2: '3.4', 3: '6', 4: '8'}
_STEADYCAM_IDLE_RIGHT_OFFSETS = {2: '0.5', 3: '0.8', 4: '1.1'}

_STEADYCAM_ELEMENT_MODS = {
    'Player_Basic_Default_Walk': {
        'Fov': ('SET', str(BASE_FOV)),
    },
    'Player_Basic_Default_Run': {
        'Fov': ('SET', str(BASE_FOV)),
    },
    'Player_Basic_Default_Runfast': {
        'Fov': ('SET', str(BASE_FOV)),
    },
    'Player_Basic_Default_Run/OffsetByVelocity': {
        'OffsetLength': ('SET', '0'),
    },
    'Player_Basic_Default_Runfast/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
        'DampSpeed': ('SET', '0.5'),
    },
    'Player_Weapon_Default_Run/OffsetByVelocity': {
        'OffsetLength': ('SET', '0'),
    },
    'Player_Weapon_Default_RunFast/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Weapon_Default_RunFast_Follow/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Animal_Default/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
    },
    'Player_Animal_Default_Run/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
    },
    'Player_Animal_Default_Run/OffsetByVelocity': {
        'OffsetLength': ('SET', '0'),
    },
    'Player_Animal_Default_Runfast/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
    },
    'Player_Animal_Default_Runfast/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
        'DampSpeed': ('SET', '0.5'),
    },
    'Player_Animal_Default_Walk/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Ride_Horse_Run': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Horse_Run/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Ride_Horse_Fast_Run': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowYawSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Horse_Fast_Run/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse_Fast_Run/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
        'DampSpeed': ('SET', '0.5'),
    },
    'Player_Ride_Horse_Dash': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowYawSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Horse_Dash/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse_Dash/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
        'DampSpeed': ('SET', '0.5'),
    },
    'Player_Ride_Horse_Dash_Att': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowYawSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Horse_Dash_Att/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse_Dash_Att/CameraDamping': {
        'PivotDampingMaxDistance': ('SET', '0.5'),
    },
    'Player_Ride_Horse_Dash_Att/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
        'DampSpeed': ('SET', '0.5'),
    },
    'Player_Ride_Horse_Att_Thrust': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowYawSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Horse_Att_L/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse_Att_L/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Ride_Horse_Att_R/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Horse_Att_R/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Ride_Elephant': {
        'FollowPitchSpeedRate': ('SET', '0.8'),
        'FollowYawSpeedRate': ('SET', '0.8'),
    },
    'Player_Ride_Elephant/CameraBlendParameter': {
        'BlendInTime': ('SET', '0.3'),
        'BlendOutTime': ('SET', '0.3'),
    },
    'Player_Ride_Elephant/CameraDamping': {
        'PivotDampingMaxDistance': ('SET', '0.5'),
    },
    'Player_Ride_Elephant/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
    'Player_Ride_Wyvern': {
        'FollowYawSpeedRate': ('SET', '0.8'),
        'FollowStartTime': ('SET', '1'),
    },
    'Player_Ride_Wyvern/OffsetByVelocity': {
        'OffsetLength': ('SET', '0.0'),
    },
}


def _build_steadycam_mods():
    """Build all steadycam modifications: FOV normalization, damping, offset stabilization."""
    mods = {key: dict(attrs) for key, attrs in _STEADYCAM_ELEMENT_MODS.items()}
    for section in _STEADYCAM_NORMALIZE_SECTIONS:
        for level, zd in _STEADYCAM_IDLE_DISTANCES.items():
            key = f'{section}/ZoomLevel[{level}]'
            mods.setdefault(key, {})['ZoomDistance'] = ('SET', zd)
        for level, ro in _STEADYCAM_IDLE_RIGHT_OFFSETS.items():
            key = f'{section}/ZoomLevel[{level}]'
            mods.setdefault(key, {})['RightOffset'] = ('SET', ro)
    return mods


# Combat

_COMBAT_WEAPON_TARGETS = {
    'wide': {2: '5', 3: '8', 4: '10'},
    'max':  {2: '6', 3: '9.5', 4: '12'},
}

_COMBAT_LOCKON_LAYERS = {
    'wide': {
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '4.5'),
        },
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '8.3'),
        },
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[4]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Force_LockOn/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '15'),
        },
        'Player_LockOn_Titan/ZoomLevel[1]': {
            'ZoomDistance': ('SET', '15'),
        },
        'Player_Weapon_LockOn/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.8'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[1]': {
            'ZoomDistance': ('SET', '5.3'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Interaction_TwoTarget/ZoomLevel[3]': {
            'MaxZoomDistance': ('SET', '10'),
        },
        'Player_Interaction_TwoTarget/ZoomLevel[4]': {
            'MaxZoomDistance': ('SET', '10'),
        },
        'Player_Weapon_LockOn_Non_Rotate/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_LockOn_WrestleOnly/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '8'),
        },
        'Player_Weapon_Throwed/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_Throw/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_CatchThrow/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '5'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[4]': {
            'ZoomDistance': ('SET', '12'),
        },
    },
    'max': {
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '6.0'),
        },
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_FollowLearn_LockOn_Boss/ZoomLevel[4]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Force_LockOn/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '20'),
        },
        'Player_LockOn_Titan/ZoomLevel[1]': {
            'ZoomDistance': ('SET', '20'),
        },
        'Player_Weapon_LockOn/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[1]': {
            'ZoomDistance': ('SET', '7.0'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Weapon_TwoTarget/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9'),
        },
        'Player_Interaction_TwoTarget/ZoomLevel[3]': {
            'MaxZoomDistance': ('SET', '10'),
        },
        'Player_Interaction_TwoTarget/ZoomLevel[4]': {
            'MaxZoomDistance': ('SET', '10'),
        },
        'Player_Weapon_LockOn_Non_Rotate/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_LockOn_WrestleOnly/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_Throwed/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_Throw/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_CatchThrow/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '9.9'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[2]': {
            'ZoomDistance': ('SET', '6'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[3]': {
            'ZoomDistance': ('SET', '10'),
        },
        'Player_Weapon_LockOn_System/ZoomLevel[4]': {
            'ZoomDistance': ('SET', '14'),
        },
    },
}


def _build_combat_weapon_mods(tier):
    """Build weapon ZoomDistance pullback for the given combat tier."""
    if tier not in _COMBAT_WEAPON_TARGETS:
        return {}
    mods = {}
    for section in _WEAPON_SECTIONS:
        for level, zd in _COMBAT_WEAPON_TARGETS[tier].items():
            key = f'{section}/ZoomLevel[{level}]'
            mods[key] = {'ZoomDistance': ('SET', zd)}
    return mods


# Always-on fixes

# Horse offset normalisation — vanilla Dash has lower RightOffset than other
# horse states, causing a visible lateral shift during speed transitions.
_HORSE_OFFSET_FIX = {
    'Player_Ride_Horse_Dash/ZoomLevel[2]': {
        'RightOffset': ('SET', '1.45'),
    },
    'Player_Ride_Horse_Dash/ZoomLevel[3]': {
        'RightOffset': ('SET', '1.8'),
    },
}


# Distance presets

_DISTANCE_PRESETS = {
    'vclose': 0.6,
    'close':  0.8,
    'default': 1.0,
    'far':    1.25,
    'vfar':   1.5,
}


# Composition

def build_modifications(style, height, fov, steadycam, combat, distance='default'):
    """Build the complete modification set from user choices.

    Args:
        style: 'shoulder' or 'centered'
        height: 'slight', 'medium', or 'vlow'
        fov: int 50-100 (0 = no change)
        steadycam: bool
        combat: 'default', 'wide', or 'max'
        distance: 'vclose', 'close', 'default', 'far', or 'vfar'

    Returns:
        ModificationSet with element_mods, fov_value, and distance_multiplier
    """
    mods = {}

    _merge(mods, _HORSE_OFFSET_FIX)
    _merge(mods, _build_height_mods(height))

    if style == 'centered':
        _merge(mods, _build_centered_mods())

    if steadycam:
        _merge(mods, _build_steadycam_mods())

    if combat in _COMBAT_LOCKON_LAYERS:
        _merge(mods, _COMBAT_LOCKON_LAYERS[combat])
        _merge(mods, _build_combat_weapon_mods(combat))

    dist_mult = _DISTANCE_PRESETS.get(distance, 1.0)

    return ModificationSet(element_mods=mods, fov_value=fov,
                           distance_multiplier=dist_mult)
