/*
 * Weapon by xUnicorn (t3rkecorejz) 
 *
 * Thanks a lot:
 *
 * Chrescoe1 & batcoh (Phenix) — First base code
 * KORD_12.7 & 406 (Nightfury) — I'm taken some functions from this authors
 * D34, 404 (Ruby) & fl0wer — Some help
 */

public stock const PluginName[ ] =			"[ZP] Weapon: Hunter Killer X-7";
public stock const PluginVersion[ ] =		"1.0";
public stock const PluginAuthor[ ] =		"Yoshioka Haruki";

/* ~ [ Includes ] ~ */
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <xs>
#include <reapi>

#include <api_muzzleflash>
#include <api_smokewallpuff>

/* ~ [ Extra Item ] ~ */
new const ExtraItem_Name[ ] =				"Hunter Killer X-7";
const ExtraItem_Cost =						0;

/* ~ [ Weapon Settings ] ~ */
const WeaponUnicalIndex =					20520221123;
new const WeaponName[ ] =					"Hunter Killer X-7";
new const WeaponReference[ ] =				"weapon_m249";
// Comment 'WeaponListDir' if u dont need custom weapon list
new const WeaponListDir[ ] =				"x_re/weapon_kronos7";
new const WeaponAnimation[ ] =				"m249";
new const WeaponNative[ ] =					"zp_give_user_kronos7";
new const WeaponModelView[ ] =				"models/x_re/v_kronos7.mdl";
new const WeaponModelPlayer[ ] =			"models/x_re/p_kronos7.mdl";
new const WeaponModelWorld[ ] =				"models/x_re/w_kronos7.mdl";
// Comment 'WeaponModelShell' if u dont need eject brass (shell) 
new const WeaponModelShell[ ] =				"models/rshell.mdl"; 
new const WeaponSounds[ ][ ] = {
	"weapons/kronos7-1.wav",
	"weapons/kronos3_beep.wav",
	"weapons/kronos3_takeaim.wav"
};

const ModelWorldBody =						0;

const WeaponMaxClip =						125; // In CSO: 150
const WeaponDefaultAmmo =					200;
const WeaponMaxAmmo =						250;

const WeaponHitCount =						50; // The count of hits on the enemy to activate the mode
const WeaponDamageMode =					19; // Damage in mode
const WeaponModeFOV =						70; // FOV: Field of view
const Float: WeaponMaxDistanceForWH =		1000.0; // Maximum distance for Wallhack
const Float: WeaponModeTime =				5.0; // Duration of the mode

const WeaponDamage =						23;
const WeaponShotPenetration =				2;
const Bullet: WeaponBulletType =			BULLET_PLAYER_762MM;
const Float: WeaponShotDistance =			8192.0;
const Float: WeaponRate =					0.1;
const Float: WeaponAccuracy =				0.2;
const Float: WeaponRangeModifier =			0.98;

#define UseDynamicCrosshair					// Comment this line if u dont need dynamic crosshair (With it not work's plugin Unlimited Clip)

#if defined _api_muzzleflash_included
	new const MuzzleFlash_SpriteTimer[ ] =	"sprites/x_re/kronos_aim_gauge_ex_128x128.spr";
	new const MuzzleFlash_SpriteBg[ ] =		"sprites/x_re/kronos_aim_bg.spr";
#endif

/* ~ [ Weapon Animations ] ~ */
enum {
	WeaponAnim_IdleA = 0,
	WeaponAnim_IdleB,
	WeaponAnim_IdleC,
	WeaponAnim_ShootA,
	WeaponAnim_ShootB,
	WeaponAnim_ShootC,
	WeaponAnim_ReloadA,
	WeaponAnim_ReloadB,
	WeaponAnim_DrawA,
	WeaponAnim_DrawB,
	WeaponAnim_ScanActivate,
	WeaponAnim_Zoom,
	WeaponAnim_ScanDeactivate,
	WeaponAnim_Dummy
};

const Float: WeaponAnim_Idle_Time =		4.0;
const Float: WeaponAnim_Shoot_Time =	0.83;
const Float: WeaponAnim_Reload_Time =	3.9;
const Float: WeaponAnim_Draw_Time =		1.0;
const Float: WeaponAnim_Scan_Time =		0.87;
const Float: WeaponAnim_Zoom_Time =		0.83;

/* ~ [ Params ] ~ */
enum (<<=1) {
	WeaponState_Mode = 1,
	WeaponState_ActivateZoom,
	WeaponState_InMode
};

enum {
	Sound_Shoot,
	Sound_Beep,
	Sound_ActivateZoom
};

new gl_iItemId;
#if defined _api_muzzleflash_included
	enum MuzzleFlashes {
		MuzzleFlash: Muzzle_Timer = 0,
		MuzzleFlash: Muzzle_BackGround
	};
	new gl_iMuzzleFlash[ MuzzleFlashes ];
#endif
#if defined WeaponModelShell
	new gl_iszModelIndex_Shell;
#endif
new gl_iszModelIndex_LaserBeam;
new HookChain: gl_HookChain_IsPenetrableEntity_Post;

/* ~ [ Macroses ] ~ */
#define Vector3(%0)						Float: %0[ 3 ]
#define IsCustomWeapon(%0,%1)			bool: ( get_entvar( %0, var_impulse ) == %1 )
#define GetWeaponState(%0)				get_member( %0, m_Weapon_iWeaponState )
#define SetWeaponState(%0,%1)			set_member( %0, m_Weapon_iWeaponState, %1 )
#define GetWeaponClip(%0)				get_member( %0, m_Weapon_iClip )
#define SetWeaponClip(%0,%1)			set_member( %0, m_Weapon_iClip, %1 )
#define GetWeaponAmmoType(%0)			get_member( %0, m_Weapon_iPrimaryAmmoType )
#define GetWeaponAmmo(%0,%1)			get_member( %0, m_rgAmmo, %1 )
#define SetWeaponAmmo(%0,%1,%2)			set_member( %0, m_rgAmmo, %1, %2 )

#define BIT_ADD(%0,%1)					( %0 |= %1 )
#define BIT_SUB(%0,%1)					( %0 &= ~%1 )
#define BIT_VALID(%0,%1)				( %0 & %1 )
#define BIT_CLEAR(%0)					( %0 = 0 )

#define m_Weapon_iHitCount				m_Weapon_iGlock18ShotsFired
#define m_Weapon_flModeTime				m_Weapon_flDecreaseShotsFired

// https://github.com/s1lentq/ReGameDLL_CS/blob/f57d28fe721ea4d57d10c010d15d45f05f2f5bad/regamedll/engine/shake.h#L43
#define FFADE_IN						0x0000 // Just here so we don't pass 0 into the function
#define FFADE_OUT						0x0001 // Fade out (not in)
#define FFADE_MODULATE					0x0002 // Modulate (don't blend)
#define FFADE_STAYOUT					0x0004 // ignores the duration, stays faded out until new ScreenFade message received

/* ~ [ AMX Mod X ] ~ */
public plugin_natives( ) register_native( WeaponNative, "native_give_user_weapon" );
public plugin_precache( ) 
{
	new iFile;

	/* -> Precache Models -> */
	engfunc( EngFunc_PrecacheModel, WeaponModelView );
	engfunc( EngFunc_PrecacheModel, WeaponModelPlayer );
	engfunc( EngFunc_PrecacheModel, WeaponModelWorld );

	#if defined _api_muzzleflash_included
		gl_iMuzzleFlash[ Muzzle_Timer ] = zc_muzzle_init( );
		{
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_Timer ], ZC_MUZZLE_SPRITE, MuzzleFlash_SpriteTimer );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_Timer ], ZC_MUZZLE_ATTACHMENT, 3 );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_Timer ], ZC_MUZZLE_FRAMERATE_MLT, WeaponModeTime );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_Timer ], ZC_MUZZLE_SCALE, 0.075 );
		}

		gl_iMuzzleFlash[ Muzzle_BackGround ] = zc_muzzle_init( );
		{
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_BackGround ], ZC_MUZZLE_SPRITE, MuzzleFlash_SpriteBg );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_BackGround ], ZC_MUZZLE_ATTACHMENT, 3 );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_BackGround ], ZC_MUZZLE_FLAGS, MuzzleFlashFlag_Static );
			zc_muzzle_set_property( gl_iMuzzleFlash[ Muzzle_BackGround ], ZC_MUZZLE_SCALE, 0.1 );
		}
	#endif

	#if defined WeaponModelShell
		gl_iszModelIndex_Shell = engfunc( EngFunc_PrecacheModel, WeaponModelShell );
	#endif

	gl_iszModelIndex_LaserBeam = engfunc( EngFunc_PrecacheModel, "sprites/laserbeam.spr" );
	
	/* -> Precache Sounds -> */
	for ( iFile = 0; iFile < sizeof WeaponSounds; iFile++ )
		engfunc( EngFunc_PrecacheSound, WeaponSounds[ iFile ] );

	#if defined WeaponListDir
		/* -> Hook Weapon -> */
		register_clcmd( WeaponListDir, "ClientCommand__HookWeapon" );

		UTIL_PrecacheWeaponList( WeaponListDir );
	#endif
}

public plugin_init( ) 
{
	// https://cso.fandom.com/wiki/Hunter_Killer_X-7
	register_plugin( PluginName, PluginVersion, PluginAuthor );

	/* -> Fakemeta -> */
	register_forward( FM_UpdateClientData, "FM_Hook_UpdateClientData_Post", true );

	/* -> ReAPI -> */
	RegisterHookChain( RG_CWeaponBox_SetModel, "RG_CWeaponBox__SetModel_Pre", false );
	DisableHookChain( gl_HookChain_IsPenetrableEntity_Post = RegisterHookChain( RG_IsPenetrableEntity, "RG_IsPenetrableEntity_Post", true ) );

	/* -> HamSandwich -> */
	RegisterHam( Ham_Spawn, WeaponReference, "Ham_CBasePlayerWeapon__Spawn_Post", true );
	RegisterHam( Ham_Item_Deploy, WeaponReference, "Ham_CBasePlayerWeapon__Deploy_Post", true );
	RegisterHam( Ham_Item_Holster, WeaponReference, "Ham_CBasePlayerWeapon__Holster_Post", true );
	#if defined WeaponListDir
		RegisterHam( Ham_Item_AddToPlayer, WeaponReference, "Ham_CBasePlayerWeapon__AddToPlayer_Post", true );
	#endif
	RegisterHam( Ham_Item_PostFrame, WeaponReference, "Ham_CBasePlayerWeapon__PostFrame_Pre", false );
	RegisterHam( Ham_Weapon_Reload, WeaponReference, "Ham_CBasePlayerWeapon__Reload_Post", true );
	RegisterHam( Ham_Weapon_WeaponIdle, WeaponReference, "Ham_CBasePlayerWeapon__WeaponIdle_Pre", false );
	RegisterHam( Ham_Weapon_PrimaryAttack, WeaponReference, "Ham_CBasePlayerWeapon__PrimaryAttack_Pre", false );
	RegisterHam( Ham_Weapon_SecondaryAttack, WeaponReference, "Ham_CBasePlayerWeapon__SecondaryAttack_Pre", false );

	/* -> Register on Extra-Items -> */
	gl_iItemId = zp_register_extra_item( ExtraItem_Name, ExtraItem_Cost, ZP_TEAM_HUMAN );
}

public bool: native_give_user_weapon( ) 
{
	enum { arg_player = 1 };

	new pPlayer = get_param( arg_player );
	if ( !is_user_alive( pPlayer ) )
		return false;
	
	return UTIL_GiveCustomWeapon( pPlayer, WeaponReference, WeaponUnicalIndex, WeaponDefaultAmmo );
}

#if defined WeaponListDir
	public ClientCommand__HookWeapon( const pPlayer ) 
	{
		engclient_cmd( pPlayer, WeaponReference );
		return PLUGIN_HANDLED;
	}
#endif

/* ~ [ Zombie Core ] ~ */
public zp_extra_item_selected( pPlayer, iItemId ) 
{
	if ( iItemId != gl_iItemId ) 
		return PLUGIN_HANDLED;

	return UTIL_GiveCustomWeapon( pPlayer, WeaponReference, WeaponUnicalIndex, WeaponDefaultAmmo ) ? PLUGIN_CONTINUE : ZP_PLUGIN_HANDLED;
}

/* ~ [ Fakemeta ] ~ */
public FM_Hook_UpdateClientData_Post( const pPlayer, const iSendWeapons, const CD_Handle ) 
{
	if ( !is_user_alive( pPlayer ) )
		return;

	static pActiveItem; pActiveItem = get_member( pPlayer, m_pActiveItem );
	if ( is_nullent( pActiveItem ) || !IsCustomWeapon( pActiveItem, WeaponUnicalIndex ) )
		return;

	set_cd( CD_Handle, CD_flNextAttack, 2.0 );
}

/* ~ [ ReAPI ] ~ */
public RG_CWeaponBox__SetModel_Pre( const pWeaponBox, const szModel[ ] ) 
{
	if ( !IsCustomWeapon( UTIL_GetWeaponBoxItem( pWeaponBox ), WeaponUnicalIndex ) )
		return HC_CONTINUE;

	SetHookChainArg( 2, ATYPE_STRING, WeaponModelWorld );
	set_entvar( pWeaponBox, var_body, ModelWorldBody );

	return HC_CONTINUE;
}

public RG_IsPenetrableEntity_Post( const Vector3( vecStart ), Vector3( vecEnd ), const pAttacker, const pHit )
{
	static iPointContents;
	if ( ( iPointContents = engfunc( EngFunc_PointContents, vecEnd ) ) && iPointContents == CONTENTS_SKY )
		return;

	if ( pHit && is_nullent( pHit ) || ( get_entvar( pHit, var_flags ) & FL_KILLME ) )
		return;

	static pActiveItem;
	if ( ( pActiveItem = get_member( pAttacker, m_pActiveItem ) ) && !is_nullent( pActiveItem ) && IsCustomWeapon( pActiveItem, WeaponUnicalIndex ) )
	{
		// In mode
		if ( BIT_VALID( GetWeaponState( pActiveItem ), WeaponState_InMode ) )
		{
			message_begin_f( MSG_ALL, SVC_TEMPENTITY );
			UTIL_TE_BEAMPOINTS( vecStart, vecEnd, gl_iszModelIndex_LaserBeam, 0, 0, 2, 3, 1, { 140, 140, 140 }, 90, 10 );
		}

		// Not in Mode
		else
		{
			if ( is_user_alive( pHit ) && get_member( pHit, m_iTeam ) != get_member( pAttacker, m_iTeam ) )
				CBasePlayerWeapon__UpdateHitCount( pAttacker, pActiveItem );
		}
	}

	if ( !ExecuteHam( Ham_IsBSPModel, pHit ) )
		return;

	UTIL_GunshotDecalTrace( pHit, vecEnd );

	if ( iPointContents == CONTENTS_WATER )
		return;

	static Vector3( vecPlaneNormal ); global_get( glb_trace_plane_normal, vecPlaneNormal );

	#if defined _api_smokewallpuff_included
		zc_smoke_wallpuff_draw( vecEnd, vecPlaneNormal );
	#endif

	xs_vec_mul_scalar( vecPlaneNormal, random_float( 25.0, 30.0 ), vecPlaneNormal );
	message_begin_f( MSG_PAS, SVC_TEMPENTITY, vecEnd );
	UTIL_TE_STREAK_SPLASH( vecEnd, vecPlaneNormal, 4, random_num( 10, 20 ), 3, 64 );
}
 
/* ~ [ HamSandwich ] ~ */
public Ham_CBasePlayerWeapon__Spawn_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	SetWeaponClip( pItem, WeaponMaxClip );
	set_member( pItem, m_Weapon_iDefaultAmmo, WeaponDefaultAmmo );
	set_member( pItem, m_Weapon_bHasSecondaryAttack, true );
	set_member( pItem, m_Weapon_iHitCount, 0 );

	#if defined WeaponListDir
		rg_set_iteminfo( pItem, ItemInfo_pszName, WeaponListDir );
	#endif

	rg_set_iteminfo( pItem, ItemInfo_iMaxClip, WeaponMaxClip );
	rg_set_iteminfo( pItem, ItemInfo_iMaxAmmo1, WeaponMaxAmmo );

	set_entvar( pItem, var_netname, WeaponName );
}

public Ham_CBasePlayerWeapon__Deploy_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	new pPlayer = get_member( pItem, m_pPlayer );

	set_entvar( pPlayer, var_viewmodel, WeaponModelView );
	set_entvar( pPlayer, var_weaponmodel, WeaponModelPlayer );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, BIT_VALID( GetWeaponState( pItem ), WeaponState_Mode ) ? WeaponAnim_DrawB : WeaponAnim_DrawA );

	set_member( pItem, m_Weapon_flAccuracy, WeaponAccuracy );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Draw_Time );
	set_member( pPlayer, m_flNextAttack, WeaponAnim_Draw_Time );
	set_member( pPlayer, m_szAnimExtention, WeaponAnimation );
}

public Ham_CBasePlayerWeapon__Holster_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	new pPlayer = get_member( pItem, m_pPlayer );

	static bitsWeaponState;
	if ( ( bitsWeaponState = GetWeaponState( pItem ) ) )
	{
		if ( BIT_VALID( bitsWeaponState, WeaponState_InMode ) )
		{
			BIT_CLEAR( bitsWeaponState );
			CBasePlayerWeapon__ResetMode( pPlayer, pItem, false );
		}
		else if ( BIT_VALID( bitsWeaponState, WeaponState_ActivateZoom ) )
			BIT_SUB( bitsWeaponState, WeaponState_ActivateZoom );

		if ( bitsWeaponState != GetWeaponState( pItem ) )
			SetWeaponState( pItem, bitsWeaponState );
	}
	
	set_member( pItem, m_Weapon_flTimeWeaponIdle, 1.0 );
	set_member( pPlayer, m_flNextAttack, 1.0 );
}

#if defined WeaponListDir
	public Ham_CBasePlayerWeapon__AddToPlayer_Post( const pItem, const pPlayer ) 
	{
		if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
			return;

		UTIL_WeaponList( MSG_ONE, pPlayer, pItem );
	}
#endif

public Ham_CBasePlayerWeapon__PostFrame_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	new pPlayer = get_member( pItem, m_pPlayer );

	#if defined UseDynamicCrosshair
		UTIL_ResetCrosshair( pPlayer, pItem );
	#endif

	static bitsWeaponState;
	if ( ( bitsWeaponState = GetWeaponState( pItem ) ) )
	{
		static Float: flGameTime; flGameTime = get_gametime( );

		// If weapon in special mode
		if ( BIT_VALID( bitsWeaponState, WeaponState_InMode ) )
		{
			// If mode time end or clip out
			if ( get_member( pItem, m_Weapon_flModeTime ) < flGameTime || !GetWeaponClip( pItem ) )
			{
				BIT_CLEAR( bitsWeaponState );
				CBasePlayerWeapon__ResetMode( pPlayer, pItem, true );
			}

			// Automatic shots
			else
			{
				ExecuteHamB( Ham_Weapon_PrimaryAttack, pItem );
				set_member( pPlayer, m_flNextAttack, WeaponRate );
			}
		}

		// If weapon activate zoom
		else if ( BIT_VALID( bitsWeaponState, WeaponState_ActivateZoom ) )
		{
			#if defined _api_muzzleflash_included
				new pSprite = NULLENT;
				if ( ( pSprite = zc_muzzle_draw( pPlayer, gl_iMuzzleFlash[ Muzzle_Timer ] ) ) && !is_nullent( pSprite ) )
					set_entvar( pSprite, var_effects, get_entvar( pSprite, var_effects ) | EF_OWNER_VISIBILITY );

				pSprite = NULLENT;
				if ( ( pSprite = zc_muzzle_draw( pPlayer, gl_iMuzzleFlash[ Muzzle_BackGround ] ) ) && !is_nullent( pSprite ) )
					set_entvar( pSprite, var_effects, get_entvar( pSprite, var_effects ) | EF_OWNER_VISIBILITY );
			
				UTIL_UpdateHideWeapon( MSG_ONE, pPlayer, get_member( pPlayer, m_iHideHUD ) | HIDEHUD_CROSSHAIR );
			#endif

			BIT_SUB( bitsWeaponState, WeaponState_ActivateZoom );
			BIT_ADD( bitsWeaponState, WeaponState_InMode );

			UTIL_SetUserFOV( MSG_ONE, pPlayer, WeaponModeFOV );
			UTIL_ScreenFade( MSG_ONE, pPlayer, 0.0, 0.0, FFADE_STAYOUT, { 252, 157, 3 }, 38 );

			rh_emit_sound2( pPlayer, 0, CHAN_STATIC, WeaponSounds[ Sound_ActivateZoom ] );

			set_member( pItem, m_Weapon_flModeTime, flGameTime + WeaponModeTime );
		}

		// If WeaponState is not similar -> update
		if ( bitsWeaponState != GetWeaponState( pItem ) )
			SetWeaponState( pItem, bitsWeaponState );
	}

	return HAM_IGNORED;
}

public Ham_CBasePlayerWeapon__Reload_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	new pPlayer = get_member( pItem, m_pPlayer );

	if ( !GetWeaponAmmo( pPlayer, GetWeaponAmmoType( pItem ) ) )
		return;

	if ( GetWeaponClip( pItem ) >= rg_get_iteminfo( pItem, ItemInfo_iMaxClip ) )
		return;

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, BIT_VALID( GetWeaponState( pItem ), WeaponState_Mode ) ? WeaponAnim_ReloadB : WeaponAnim_ReloadA );

	set_member( pPlayer, m_flNextAttack, WeaponAnim_Reload_Time );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Reload_Time );
}

public Ham_CBasePlayerWeapon__WeaponIdle_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) || get_member( pItem, m_Weapon_flTimeWeaponIdle ) > 0.0 )
		return HAM_IGNORED;

	new pPlayer = get_member( pItem, m_pPlayer );
	static bitsWeaponState; bitsWeaponState = GetWeaponState( pItem );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, BIT_VALID( bitsWeaponState, WeaponState_InMode ) ? WeaponAnim_IdleC : BIT_VALID( bitsWeaponState, WeaponState_Mode ) ? WeaponAnim_IdleB : WeaponAnim_IdleA );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Idle_Time );

	return HAM_SUPERCEDE;
}

public Ham_CBasePlayerWeapon__PrimaryAttack_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	new iClip = GetWeaponClip( pItem );
	if ( !iClip ) 
	{
		ExecuteHam( Ham_Weapon_PlayEmptySound, pItem );
		set_member( pItem, m_Weapon_flNextPrimaryAttack, 0.2 );

		return HAM_SUPERCEDE;
	}

	new pPlayer = get_member( pItem, m_pPlayer );
	static bitsWeaponState; bitsWeaponState = GetWeaponState( pItem );

	new bitsFlags = get_entvar( pPlayer, var_flags );
	new iShotsFired = get_member( pItem, m_Weapon_iShotsFired ); iShotsFired++;
	new Float: flAccuracy = BIT_VALID( bitsWeaponState, WeaponState_InMode ) ? 0.1 : get_member( pItem, m_Weapon_flAccuracy );
	new Float: flSpread = ( ( ~bitsFlags & FL_ONGROUND ) ? 0.2 : 0.08 ) * flAccuracy;

	if ( flAccuracy )
		flAccuracy = floatmin( ( ( iShotsFired * iShotsFired ) / 220.0 ) + 0.30, 1.0 );

	static Vector3( vecSrc ); UTIL_GetEyePosition( pPlayer, vecSrc );
	static Vector3( vecAiming ); UTIL_GetVectorAiming( pPlayer, vecAiming );

	// In Mode
	if ( BIT_VALID( bitsWeaponState, WeaponState_InMode ) )
	{
		new Array: arValidVictims = ArrayCreate( .reserved = 0 );
		CBasePlayerWeapon__ScanVictims( pPlayer, arValidVictims );

		static iArraySize; iArraySize = ArraySize( arValidVictims );
		if ( iArraySize )
		{
			static Vector3( vecVictimOrigin );
			for ( new i; i < iArraySize; i++ )
			{
				get_entvar( ArrayGetCell( arValidVictims, i ), var_origin, vecVictimOrigin );
				xs_vec_sub( vecVictimOrigin, vecSrc, vecAiming );

				CBasePlayerWeapon__Fire( pPlayer, pItem, vecSrc, vecAiming, flSpread, WeaponDamageMode );
			}
		}
		else CBasePlayerWeapon__Fire( pPlayer, pItem, vecSrc, vecAiming, flSpread, WeaponDamageMode );

		ArrayDestroy( arValidVictims );
	}

	// Default shoots
	else
	{
		CBasePlayerWeapon__Fire( pPlayer, pItem, vecSrc, vecAiming, flSpread, WeaponDamage );

		static Vector3( vecVelocity ); get_entvar( pPlayer, var_velocity, vecVelocity );

		if ( xs_vec_len_2d( vecVelocity ) > 0 ) 
			UTIL_WeaponKickBack( pItem, pPlayer, 1.0, 0.45, 0.28, 0.04, 4.25, 2.5, 7 );
		else if ( ~bitsFlags & FL_ONGROUND ) 
			UTIL_WeaponKickBack( pItem, pPlayer, 1.25, 0.45, 0.22, 0.18, 6.0, 4.0, 5 );
		else if ( bitsFlags & FL_DUCKING ) 
			UTIL_WeaponKickBack( pItem, pPlayer, 0.6, 0.35, 0.2, 0.0125, 3.7, 2.0, 10 );
		else
			UTIL_WeaponKickBack( pItem, pPlayer, 0.625, 0.375, 0.25, 0.0125, 4.0, 2.25, 9 );
	}

	#if defined UseDynamicCrosshair
		UTIL_IncreaseCrosshair( pPlayer, pItem );
	#endif
	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, 
		BIT_VALID( bitsWeaponState, WeaponState_InMode ) ? WeaponAnim_ShootC : 
		BIT_VALID( bitsWeaponState, WeaponState_Mode ) ? WeaponAnim_ShootB : 
		WeaponAnim_ShootA );
	rg_set_animation( pPlayer, PLAYER_ATTACK1 );
	rh_emit_sound2( pPlayer, 0, CHAN_WEAPON, WeaponSounds[ Sound_Shoot ] );

	if ( BIT_VALID( bitsWeaponState, WeaponState_InMode ) )
		rh_emit_sound2( pPlayer, 0, CHAN_STATIC, WeaponSounds[ Sound_Beep ] );

	#if defined WeaponModelShell
		set_member( pItem, m_Weapon_iShellId, gl_iszModelIndex_Shell );
		set_member( pPlayer, m_flEjectBrass, get_gametime( ) );
	#endif

	SetWeaponClip( pItem, --iClip );
	set_member( pItem, m_Weapon_flAccuracy, flAccuracy );
	set_member( pItem, m_Weapon_iShotsFired, iShotsFired );
	set_member( pItem, m_Weapon_flNextPrimaryAttack, WeaponRate );
	set_member( pItem, m_Weapon_flNextSecondaryAttack, WeaponRate );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Shoot_Time );

	return HAM_SUPERCEDE;
}

public Ham_CBasePlayerWeapon__SecondaryAttack_Pre( const pItem )
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	static bitsWeaponState; bitsWeaponState = GetWeaponState( pItem );
	if ( !BIT_VALID( bitsWeaponState, WeaponState_Mode ) || BIT_VALID( bitsWeaponState, WeaponState_InMode ) )
		return HAM_IGNORED;

	new pPlayer = get_member( pItem, m_pPlayer );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_Zoom );

	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Zoom_Time );
	set_member( pItem, m_Weapon_flNextPrimaryAttack, WeaponAnim_Zoom_Time );
	set_member( pItem, m_Weapon_flNextSecondaryAttack, WeaponAnim_Zoom_Time );
	set_member( pPlayer, m_flNextAttack, WeaponAnim_Zoom_Time );

	BIT_ADD( bitsWeaponState, WeaponState_ActivateZoom );
	SetWeaponState( pItem, bitsWeaponState );

	return HAM_SUPERCEDE;
}

public bool: CBasePlayerWeapon__ResetMode( const pPlayer, const pItem, const bool: bWithAnimation )
{
	#if defined _api_muzzleflash_included
		if ( is_user_connected( pPlayer ) )
		{
			zc_muzzle_destroy( pPlayer, gl_iMuzzleFlash[ Muzzle_Timer ] );
			zc_muzzle_destroy( pPlayer, gl_iMuzzleFlash[ Muzzle_BackGround ] );
		}

		UTIL_UpdateHideWeapon( MSG_ONE, pPlayer, get_member( pPlayer, m_iHideHUD ) & ~HIDEHUD_CROSSHAIR );
	#endif

	UTIL_SetUserFOV( MSG_ONE, pPlayer );
	UTIL_ScreenFade( MSG_ONE, pPlayer, 0.0, 0.0, FFADE_IN, { 0, 0, 0 }, 255 );

	set_member( pItem, m_Weapon_flAccuracy, WeaponAccuracy );
	set_member( pItem, m_Weapon_iShotsFired, 0 );

	if ( bWithAnimation )
	{
		UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_ScanDeactivate );

		set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Scan_Time );
		set_member( pItem, m_Weapon_flNextPrimaryAttack, WeaponAnim_Scan_Time );
		set_member( pItem, m_Weapon_flNextSecondaryAttack, WeaponAnim_Scan_Time );
		set_member( pPlayer, m_flNextAttack, WeaponAnim_Scan_Time );
	}
}

public bool: CBasePlayerWeapon__UpdateHitCount( const pPlayer, const pItem )
{
	static bitsWeaponState;
	if ( ( bitsWeaponState = GetWeaponState( pItem ) ) )
		return false;

	static iHitCount; iHitCount = get_member( pItem, m_Weapon_iHitCount )
	if ( ++iHitCount && iHitCount >= WeaponHitCount )
	{
		iHitCount = 0;
		BIT_ADD( bitsWeaponState, WeaponState_Mode );

		UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_ScanActivate );
		set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Scan_Time );
	}

	set_member( pItem, m_Weapon_iHitCount, iHitCount );

	if ( bitsWeaponState != GetWeaponState( pItem ) )
		SetWeaponState( pItem, bitsWeaponState );

	return true;
}

public CBasePlayerWeapon__Fire( const pPlayer, const pItem, const Vector3( vecOrigin ), const Vector3( vecAiming ), const Float: flSpread, const iDamage )
{
	static Vector3( vecSrc ); xs_vec_copy( vecOrigin, vecSrc );
	static Vector3( vecDirection ); xs_vec_copy( vecAiming, vecDirection );

	EnableHookChain( gl_HookChain_IsPenetrableEntity_Post );
	rg_fire_bullets3( pItem, pPlayer, vecSrc, vecDirection, flSpread, WeaponShotDistance, WeaponShotPenetration, WeaponBulletType, iDamage, WeaponRangeModifier, false, get_member( pPlayer, random_seed ) );
	DisableHookChain( gl_HookChain_IsPenetrableEntity_Post );
}

public CBasePlayerWeapon__ScanVictims( const pPlayer, &Array: arValidVictims )
{
	static Vector3( vecVictimOrigin );
	static Vector3( vecOrigin ); get_entvar( pPlayer, var_origin, vecOrigin );

	static aPlayers[ MAX_CLIENTS ], iPlayersNum;
	get_players( aPlayers, iPlayersNum, "aeh", "TERRORIST" );

	for ( new i, pVictim = NULLENT; i < iPlayersNum; i++ )
	{
		pVictim = aPlayers[ i ];

		get_entvar( pVictim, var_origin, vecVictimOrigin );

		static Float: flDistance; flDistance = xs_vec_distance( vecOrigin, vecVictimOrigin );
		if ( flDistance >= WeaponMaxDistanceForWH )
			continue;

		if ( ExecuteHam( Ham_FInViewCone, pPlayer, pVictim ) )
		{
			if ( !UTIL_IsWallBetweenPoints( pPlayer, pVictim ) )
			{
				/**
				 * From Lite ESP
				 * Source: https://goldsrc.ru/resources/200/
				 **/

				static pTrace; pTrace = create_tr2( );
				engfunc( EngFunc_TraceLine, vecOrigin, vecVictimOrigin, IGNORE_MONSTERS, -1, pTrace );
				static Vector3( vecEndPos ); get_tr2( pTrace, TR_vecEndPos, vecEndPos );
				free_tr2( pTrace );

				static Float: flDistanceToEndPos; flDistanceToEndPos = xs_vec_distance( vecOrigin, vecEndPos );
				if ( floatcmp( flDistance, flDistanceToEndPos ) == 0 )
					continue;

				static Vector3( vecCentre ); xs_vec_sub( vecVictimOrigin, vecOrigin, vecCentre );
				static Vector3( vecOffset ); xs_vec_copy( vecCentre, vecOffset );
				xs_vec_div_scalar( vecOffset, xs_vec_len( vecCentre ), vecOffset );
				xs_vec_mul_scalar( vecOffset, flDistanceToEndPos - 10.0, vecOffset );

				static Vector3( vecEyeLevel ); xs_vec_copy( vecOrigin, vecEyeLevel );
				vecEyeLevel[ 2 ] += 17.5; xs_vec_add( vecOffset, vecEyeLevel, vecOffset );
				static Vector3( vecStart ); xs_vec_copy( vecOffset, vecStart );
				static Vector3( vecEnd ); xs_vec_copy( vecOffset, vecEnd );
				static Float: flScaledBoneLen; flScaledBoneLen = flDistanceToEndPos / flDistance * 50.0;
				vecEnd[ 2 ] -= flScaledBoneLen;

				message_begin_f( MSG_ONE, SVC_TEMPENTITY, .player = pPlayer );
				UTIL_TE_BEAMPOINTS( vecStart, vecEnd, gl_iszModelIndex_LaserBeam, 3, 0, 1, floatround( flScaledBoneLen * 3.0 ), 0, { 255, 0, 0 }, 128, 0 );
			}
			else ArrayPushCell( arValidVictims, pVictim );
		}
	}
}

/* ~ [ Stocks ] ~ */

/* -> Give Custom Item <- */
stock bool: UTIL_GiveCustomWeapon( const pPlayer, const szWeaponReference[ ], const iWeaponUId, const iDefaultAmmo, &pItem = NULLENT )
{
	pItem = rg_give_custom_item( pPlayer, szWeaponReference, GT_DROP_AND_REPLACE, iWeaponUId );
	if ( is_nullent( pItem ) )
		return false;

	if ( iDefaultAmmo )
	{
		new iAmmoType = GetWeaponAmmoType( pItem );
		if ( GetWeaponAmmo( pPlayer, iAmmoType ) > iDefaultAmmo )
			SetWeaponAmmo( pPlayer, iDefaultAmmo, iAmmoType );
	}

	return true;
}

/* -> Weapon Animation <- */
stock UTIL_SendWeaponAnim( const iDest, const pReceiver, const pItem, const iAnim ) 
{
	static iBody; iBody = get_entvar( pItem, var_body );
	set_entvar( pReceiver, var_weaponanim, iAnim );

	message_begin( iDest, SVC_WEAPONANIM, .player = pReceiver );
	write_byte( iAnim );
	write_byte( iBody );
	message_end( );

	if ( get_entvar( pReceiver, var_iuser1 ) )
		return;

	static i, iCount, pSpectator, iszSpectators[ MAX_PLAYERS ];
	get_players( iszSpectators, iCount, "bch" );

	for ( i = 0; i < iCount; i++ )
	{
		pSpectator = iszSpectators[ i ];

		if ( get_entvar( pSpectator, var_iuser1 ) != OBS_IN_EYE )
			continue;

		if ( get_entvar( pSpectator, var_iuser2 ) != pReceiver )
			continue;

		set_entvar( pSpectator, var_weaponanim, iAnim );

		message_begin( iDest, SVC_WEAPONANIM, .player = pSpectator );
		write_byte( iAnim );
		write_byte( iBody );
		message_end( );
	}
}

/* -> Get Vector Aiming <- */
stock UTIL_GetVectorAiming( const pPlayer, Vector3( vecAiming ) ) 
{
	static Vector3( vecViewAngle ); get_entvar( pPlayer, var_v_angle, vecViewAngle );
	static Vector3( vecPunchangle ); get_entvar( pPlayer, var_punchangle, vecPunchangle );

	xs_vec_add( vecViewAngle, vecPunchangle, vecViewAngle );
	angle_vector( vecViewAngle, ANGLEVECTOR_FORWARD, vecAiming );
}

/* -> Get player eye position <- */
stock UTIL_GetEyePosition( const pPlayer, Vector3( vecEyeLevel ) )
{
	static Vector3( vecOrigin ); get_entvar( pPlayer, var_origin, vecOrigin );
	static Vector3( vecViewOfs ); get_entvar( pPlayer, var_view_ofs, vecViewOfs );

	xs_vec_add( vecOrigin, vecViewOfs, vecEyeLevel );
}

/* -> The target is behind the wall <- */
stock bool: UTIL_IsWallBetweenPoints( const pPlayer, const pTarget )
{
	if ( is_nullent( pPlayer) || is_nullent( pTarget ) )
		return false;

	static Vector3( vecStart ); get_entvar( pPlayer, var_origin, vecStart );
	static Vector3( vecEnd ); get_entvar( pTarget, var_origin, vecEnd );

	static pTrace; pTrace = create_tr2( );
	engfunc( EngFunc_TraceLine, vecStart, vecEnd, IGNORE_MONSTERS, pPlayer, pTrace );
	static Vector3( vecEndPos ); get_tr2( pTrace, TR_vecEndPos, vecEndPos );
	free_tr2( pTrace );

	return xs_vec_equal( vecEnd, vecEndPos );
}

/* -> Dynamic Crosshair <- */
stock UTIL_IncreaseCrosshair( const pPlayer, const pItem, iFakePosition = 13, iFakeWeaponId = CSW_MAC10 )
{
	if ( BIT( get_member( pItem, m_iId ) ) & ( BIT( CSW_MAC10 ) | BIT( CSW_M3 ) | BIT( CSW_XM1014 ) ) )
		return;
	
	if ( get_member( pPlayer, m_iFOV ) < 55 || get_member( pPlayer, m_iHideHUD ) & HIDEHUD_CROSSHAIR )
		return;

	static iMsgId_CurWeapon; if ( !iMsgId_CurWeapon ) iMsgId_CurWeapon = get_user_msgid( "CurWeapon" );

	set_msg_block( iMsgId_CurWeapon, BLOCK_ONCE );

	if ( rg_get_iteminfo( pItem, ItemInfo_iSlot ) != 0 )
	{
		new pWeapon = get_member( pPlayer, m_rgpPlayerItems, PRIMARY_WEAPON_SLOT );
		if ( !is_nullent( pWeapon ) && get_member( pWeapon, m_iId ) == iFakeWeaponId )
			iFakePosition = 12, iFakeWeaponId = CSW_XM1014;
	}

	UTIL_WeaponList( MSG_ONE, pPlayer, pItem, .iPosition = iFakePosition, .iWeaponId = iFakeWeaponId );
	UTIL_CurWeapon( MSG_ONE, pPlayer, true, iFakeWeaponId, GetWeaponClip( pItem ) );

	set_member( pItem, m_Weapon_flNextReload, get_gametime( ) + 0.04 );
}

stock UTIL_ResetCrosshair( const pPlayer, const pItem ) 
{
	if ( get_member( pItem, m_Weapon_flNextReload ) && get_member( pItem, m_Weapon_flNextReload ) <= get_gametime( ) ) 
	{
		UTIL_CurWeapon( MSG_ONE, pPlayer, true, get_member( pItem, m_iId ), GetWeaponClip( pItem ) );
		set_member( pItem, m_Weapon_flNextReload, 0.0 );
	}
}

/* -> Weapon Kick Back <- */
stock UTIL_WeaponKickBack( const pItem, const pPlayer, Float: flUpBase, Float: flLateralBase, Float: flUpModifier, Float: flLateralModifier, Float: flUpMax, Float: flLateralMax, iDirectionChange ) 
{
	new Float: flKickUp, Float: flKickLateral;
	new iShotsFired = get_member( pItem, m_Weapon_iShotsFired );
	new iDirection = get_member( pItem, m_Weapon_iDirection );
	new Vector3( vecPunchangle ); get_entvar( pPlayer, var_punchangle, vecPunchangle );

	if ( iShotsFired == 1 ) 
	{
		flKickUp = flUpBase;
		flKickLateral = flLateralBase;
	}
	else
	{
		flKickUp = iShotsFired * flUpModifier + flUpBase;
		flKickLateral = iShotsFired * flLateralModifier + flLateralBase;
	}

	vecPunchangle[ 0 ] -= flKickUp;

	if ( vecPunchangle[ 0 ] < -flUpMax ) 
		vecPunchangle[ 0 ] = -flUpMax;

	if ( iDirection ) 
	{
		vecPunchangle[ 1 ] += flKickLateral;
		if ( vecPunchangle[ 1 ] > flLateralMax ) 
			vecPunchangle[ 1 ] = flLateralMax;
	}
	else
	{
		vecPunchangle[ 1 ] -= flKickLateral;
		if ( vecPunchangle[ 1 ] < -flLateralMax ) 
			vecPunchangle[ 1 ] = -flLateralMax;
	}

	if ( !random_num( 0, iDirectionChange ) ) 
		set_member( pItem, m_Weapon_iDirection, iDirection );

	set_entvar( pPlayer, var_punchangle, vecPunchangle );
}

/* -> Get Weapon Box Item <- */
stock UTIL_GetWeaponBoxItem( const pWeaponBox )
{
	for ( new iSlot, pItem; iSlot < MAX_ITEM_TYPES; iSlot++ )
	{
		if ( !is_nullent( ( pItem = get_member( pWeaponBox, m_WeaponBox_rgpPlayerItems, iSlot ) ) ) )
			return pItem;
	}
	return NULLENT;
}

/* -> Automaticly precache WeaponList <- */
stock UTIL_PrecacheWeaponList( const szWeaponList[ ] )
{
	new szBuffer[ 128 ], pFile;

	format( szBuffer, charsmax( szBuffer ), "sprites/%s.txt", szWeaponList );
	engfunc( EngFunc_PrecacheGeneric, szBuffer );

	if ( !( pFile = fopen( szBuffer, "rb" ) ) )
		return;

	new szSprName[ MAX_RESOURCE_PATH_LENGTH ], iPos;

	while ( !feof( pFile ) ) 
	{
		fgets( pFile, szBuffer, charsmax( szBuffer ) );
		trim( szBuffer );

		if ( !strlen( szBuffer ) ) 
			continue;

		if ( ( iPos = containi( szBuffer, "640" ) ) == -1 )
			continue;
				
		format( szBuffer, charsmax( szBuffer ), "%s", szBuffer[ iPos + 3 ] );		
		trim( szBuffer );

		strtok( szBuffer, szSprName, charsmax( szSprName ), szBuffer, charsmax( szBuffer ), ' ', 1 );
		trim( szSprName );

		engfunc( EngFunc_PrecacheGeneric, fmt( "sprites/%s.spr", szSprName ) );
	}

	fclose( pFile );
}

/* -> Gunshot Decal Trace <- */
stock UTIL_GunshotDecalTrace( const pEntity, const Vector3( vecOrigin ) )
{	
	new iDecalId = UTIL_DamageDecal( pEntity );
	if ( iDecalId == -1 )
		return;

	message_begin_f( MSG_PAS, SVC_TEMPENTITY, vecOrigin );
	UTIL_TE_GUNSHOTDECAL( vecOrigin, pEntity, iDecalId );
}

stock UTIL_DamageDecal( const pEntity )
{
	new iRenderMode = get_entvar( pEntity, var_rendermode );
	if ( iRenderMode == kRenderTransAlpha )
		return -1;

	static iGlassDecalId; if ( !iGlassDecalId ) iGlassDecalId = engfunc( EngFunc_DecalIndex, "{bproof1" );
	if ( iRenderMode != kRenderNormal )
		return iGlassDecalId;

	static iShotDecalId; if ( !iShotDecalId ) iShotDecalId = engfunc( EngFunc_DecalIndex, "{shot1" );
	return ( iShotDecalId - random_num( 0, 4 ) );
}

/* -> Weapon List <- */
stock UTIL_WeaponList( const iDest, const pReceiver, const pItem, szWeaponName[ MAX_NAME_LENGTH ] = "", const iPrimaryAmmoType = -2, iMaxPrimaryAmmo = -2, iSecondaryAmmoType = -2, iMaxSecondaryAmmo = -2, iSlot = -2, iPosition = -2, iWeaponId = -2, iFlags = -2 ) 
{
	if ( szWeaponName[ 0 ] == EOS )
		rg_get_iteminfo( pItem, ItemInfo_pszName, szWeaponName, charsmax( szWeaponName ) )

	static iMsgId_Weaponlist; if ( !iMsgId_Weaponlist ) iMsgId_Weaponlist = get_user_msgid( "WeaponList" );

	message_begin( iDest, iMsgId_Weaponlist, .player = pReceiver );
	write_string( szWeaponName );
	write_byte( ( iPrimaryAmmoType <= -2 ) ? GetWeaponAmmoType( pItem ) : iPrimaryAmmoType );
	write_byte( ( iMaxPrimaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo1 ) : iMaxPrimaryAmmo );
	write_byte( ( iSecondaryAmmoType <= -2 ) ? get_member( pItem, m_Weapon_iSecondaryAmmoType ) : iSecondaryAmmoType );
	write_byte( ( iMaxSecondaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo2 ) : iMaxSecondaryAmmo );
	write_byte( ( iSlot <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iSlot ) : iSlot );
	write_byte( ( iPosition <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iPosition ) : iPosition );
	write_byte( ( iWeaponId <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iId ) : iWeaponId );
	write_byte( ( iFlags <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iFlags ) : iFlags );
	message_end( );
}

/* -> Cur Weapon <- */
stock UTIL_CurWeapon( const iDest, const pReceiver, const bool: bIsActive, const iWeaponId, const iClipAmmo )
{
	static iMsgId_CurWeapon; if ( !iMsgId_CurWeapon ) iMsgId_CurWeapon = get_user_msgid( "CurWeapon" );

	message_begin( iDest, iMsgId_CurWeapon, .player = pReceiver );
	write_byte( bIsActive );
	write_byte( iWeaponId );
	write_byte( iClipAmmo );
	message_end( );
}

/* -> Update HideWeapon <- */
stock UTIL_UpdateHideWeapon( const iDest, const pReceiver, const bitsFlags )
{
	static iMsgId_HideWeapon; if ( !iMsgId_HideWeapon ) iMsgId_HideWeapon = get_user_msgid( "HideWeapon" );

	message_begin( iDest, iMsgId_HideWeapon, .player = pReceiver );
	write_byte( bitsFlags );
	message_end( );

	set_member( pReceiver, m_iHideHUD, bitsFlags );
	set_member( pReceiver, m_iClientHideHUD, bitsFlags );
}

/* -> Set user FOV <- */
stock UTIL_SetUserFOV( const iDest, const pReceiver, const iFOV = DEFAULT_NO_ZOOM )
{
	static iMsgId_SetFOV; if ( !iMsgId_SetFOV ) iMsgId_SetFOV = get_user_msgid( "SetFOV" );

	message_begin( iDest, iMsgId_SetFOV, .player = pReceiver );
	write_byte( iFOV );
	message_end( );

	set_entvar( pReceiver, var_fov, iFOV );
	set_member( pReceiver, m_iFOV, iFOV );
}

/* -> Converting a float to a bit value <- */
stock FixedUnsigned16( Float: flValue, iScale = ( 1<<12 ) )
	return clamp( floatround( flValue * iScale ), 0, 0xFFFF );

/* -> ScreenFade <- */
stock UTIL_ScreenFade( const iDest, const pReceiver, Float: flDuration, Float: flHoldTime, const bitsFlags, const iColor[ 3 ], const iAlpha )
{
	static iMsgId_ScreenFade; if ( !iMsgId_ScreenFade ) iMsgId_ScreenFade = get_user_msgid( "ScreenFade" );

	message_begin( iDest, iMsgId_ScreenFade, .player = pReceiver );
	write_short( FixedUnsigned16( flDuration ) ); // Duration
	write_short( FixedUnsigned16( flHoldTime ) ); // Hold Time
	write_short( bitsFlags ); // Flags
	write_byte( iColor[ 0 ] ); // Red
	write_byte( iColor[ 1 ] ); // Green
	write_byte( iColor[ 2 ] ); // Blue
	write_byte( iAlpha ); // Alpha
	message_end( );
}

/* -> TE_BEAMPOINTS <- */
stock UTIL_TE_BEAMPOINTS( const Vector3( vecStart ), const Vector3( vecEnd ), const iszModelIndex, const iStartFrame, const iFrameRate, const iLife, const iWidth, const iNoise, const iColor[ 3 ], const iBrightness, const iScroll )
{
	write_byte( TE_BEAMPOINTS );
	write_coord_f( vecStart[ 0 ] );
	write_coord_f( vecStart[ 1 ] );
	write_coord_f( vecStart[ 2 ] );
	write_coord_f( vecEnd[ 0 ] );
	write_coord_f( vecEnd[ 1 ] );
	write_coord_f( vecEnd[ 2 ] );
	write_short( iszModelIndex ); // Model Index
	write_byte( iStartFrame ); // Start Frame
	write_byte( iFrameRate ); // FrameRate
	write_byte( iLife ); // Life in 0.1's
	write_byte( iWidth ); // Line width in 0.1's
	write_byte( iNoise ); // Noise
	write_byte( iColor[ 0 ] ); // Red
	write_byte( iColor[ 1 ] ); // Green
	write_byte( iColor[ 2 ] ); // Blue
	write_byte( iBrightness ); // Brightness
	write_byte( iScroll ); // Scroll speed in 0.1's
	message_end( );
}

/* -> TE_STREAK_SPLASH <- */
stock UTIL_TE_STREAK_SPLASH( const Vector3( vecOrigin ), const Vector3( vecDirection ), const iColor, const iCount, const iSpeed, const iNoise )
{
	write_byte( TE_STREAK_SPLASH );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] );
	write_coord_f( vecDirection[ 0 ] );
	write_coord_f( vecDirection[ 1 ] );
	write_coord_f( vecDirection[ 2 ] );
	write_byte( iColor );
	write_short( iCount );
	write_short( iSpeed );
	write_short( iNoise );
	message_end( );
}

/* -> TE_GUNSHOTDECAL <- */
stock UTIL_TE_GUNSHOTDECAL( const Vector3( vecOrigin ), const pEntity, const iDecalId )
{
	write_byte( TE_GUNSHOTDECAL );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] );
	write_short( pEntity );
	write_byte( iDecalId );
	message_end( );
}
